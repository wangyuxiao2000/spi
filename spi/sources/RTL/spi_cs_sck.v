/*************************************************************/
//function: spi master的CS/SCK时序控制器
//Author  : WangYuxiao
//Email   : wyxee2000@163.com
//Data    : 2023.09.15
//Version : V 1.0
/*************************************************************/
`timescale 1 ns / 1 ns

module spi_cs_sck (clk,rst_n,en,cpol,cpha,w_r_mode,wr_width,rd_width,cs,sck);
/*******************************************工作参数设置******************************************/
parameter system_clk=50_000000;    /*定义系统时钟频率(Hz)*/
parameter spi_rate=5_000000;       /*定义SPI速率(bps)*/
parameter cs_buff_time=10;         /*cs在下降沿前稳定保持高电平的缓冲时间(unit:一个数据长度)*/
parameter sck_buff_time=4;         /*cs拉低-sck启动/sck停止-cs拉高 之间的缓冲时间(unit:一个数据长度)*/
localparam N=((system_clk/spi_rate)<4)?4:(system_clk/spi_rate); /*计算分频系数(至少为4)*/
localparam cs_buff_time_tot=cs_buff_time*N;
localparam sck_buff_time_tot=sck_buff_time*N;
/************************************************************************************************/
input clk;            /*系统时钟*/
input rst_n;          /*低电平异步复位信号*/
input en;             /*模块启动信号*/
input cpol;           /*时钟空闲态:cpol=0时,空闲为低; cpol=1时,空闲为高*/
input cpha;           /*时钟相位:cpha=0时,在奇数个时钟边沿采样; cpha=1时,在偶数个时钟边沿采样*/
input [1:0] w_r_mode; /*00-只读模式; 01-只写模式; 10-指令控读模式*/
input [5:0] wr_width; /*本次SPI写传输位宽(最大支持32bit)*/
input [5:0] rd_width; /*本次SPI读传输位宽(最大支持32bit)*/
output sck;           /*sck时钟输出*/
output reg cs;        /*cs片选信号输出*/



/*******************************************产生cs信号********************************************/
reg [1:0] state;
localparam STATE_cs_buff=2'b00;         /*传输启动后,延迟一定时间,拉低cs信号*/
localparam STATE_sck_start_buff=2'b01;  /*cs信号拉低后,延迟一定时间,启动sck信号*/
localparam STATE_transfer=2'b11;        /*产生sck信号*/
localparam STATE_sck_over_buff=2'b10;   /*sck信号结束后,延迟一定时间,拉高cs信号*/

reg [6:0] data_tot;
reg [5:0] data_cnt;
reg [((((cs_buff_time_tot-1)&(cs_buff_time_tot-1-1))==0)?$clog2(cs_buff_time_tot-1):($clog2(cs_buff_time_tot-1)-1)):0] cs_buff_time_cnt;
reg [((((sck_buff_time_tot-1)&(sck_buff_time_tot-1-1))==0)?$clog2(sck_buff_time_tot-1):($clog2(sck_buff_time_tot-1)-1)):0] sck_buff_time_cnt;
reg sck_en;
reg sck_reg;

always@(*)
begin
  case(w_r_mode)
    2'd0 : data_tot=rd_width;
    2'd1 : data_tot=wr_width;
    2'd2 : data_tot=wr_width+rd_width;
    default : data_tot=wr_width+rd_width;
  endcase
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    sck_reg<=cpol;
  else
    sck_reg<=sck;
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    begin
      state<=STATE_cs_buff;
      cs_buff_time_cnt<=0;
      sck_buff_time_cnt<=0;
      cs<=1;
      sck_en<=0;
      data_cnt<=0;
    end
  else if(en)
    begin
      case(state)
        STATE_cs_buff : begin
                          if(cs_buff_time_cnt==cs_buff_time_tot-1)
                            begin
                              state<=STATE_sck_start_buff;
                              cs_buff_time_cnt<=0;
                              cs<=0;
                              sck_en<=0;
                              data_cnt<=0;
                            end
                          else
                            begin
                              state<=state;
                              cs_buff_time_cnt<=cs_buff_time_cnt+1;
                              cs<=1;
                              sck_en<=0;
                              data_cnt<=0;
                            end
                        end

        STATE_sck_start_buff : begin
                                 if(sck_buff_time_cnt==sck_buff_time_tot-1)
                                   begin
                                     state<=STATE_transfer;
                                     sck_buff_time_cnt<=0;
                                     sck_en<=1;
                                     data_cnt<=0;
                                   end
                                 else
                                   begin
                                     state<=state;
                                     sck_buff_time_cnt<=sck_buff_time_cnt+1;
                                     sck_en<=0;
                                     data_cnt<=0;
                                   end
                               end

        STATE_transfer : begin
                           case({cpol,cpha})
                             2'b00 : begin
                                       if(!sck_reg&&sck)
                                         begin
                                           if(data_cnt==data_tot-1)
                                             data_cnt<=0;
                                           else
                                             data_cnt<=data_cnt+1;
                                         end
                                       else
                                         data_cnt<=data_cnt;

                                       if(data_cnt==0&&sck_reg&&!sck)/*传输完最后一个数据后,等待sck自然变化至空闲电平,再关闭sck_en*/
                                         begin
                                           state<=STATE_sck_over_buff;
                                           sck_en<=0;
                                         end
                                       else
                                         begin
                                           state<=state;
                                           sck_en<=1;
                                         end
                                     end

                             2'b01 : begin
                                       if(sck_reg&&!sck)
                                         begin
                                           if(data_cnt==data_tot-1)
                                             begin
                                               state<=STATE_sck_over_buff;
                                               sck_en<=0;
                                               data_cnt<=0;
                                             end
                                           else
                                             begin
                                               state<=state;
                                               sck_en<=1;
                                               data_cnt<=data_cnt+1;
                                             end                                     
                                         end
                                       else
                                         begin
                                           state<=state;
                                           sck_en<=1;
                                           data_cnt<=data_cnt;
                                         end
                                     end

                             2'b10 : begin
                                       if(sck_reg&&!sck)
                                         begin
                                           if(data_cnt==data_tot-1)
                                             data_cnt<=0;
                                           else
                                             data_cnt<=data_cnt+1;
                                         end
                                       else
                                         data_cnt<=data_cnt;

                                       if(data_cnt==0&&!sck_reg&&sck)/*传输完最后一个数据后,等待sck自然变化至空闲电平,再关闭sck_en*/
                                         begin
                                           state<=STATE_sck_over_buff;
                                           sck_en<=0;
                                         end
                                       else
                                         begin
                                           state<=state;
                                           sck_en<=1;
                                         end
                                     end
         
                             2'b11 : begin
                                       if(!sck_reg&&sck)
                                       begin
                                         if(data_cnt==data_tot-1)
                                           begin
                                             state<=STATE_sck_over_buff;
                                             sck_en<=0;
                                             data_cnt<=0;
                                           end
                                         else
                                           begin
                                             state<=state;
                                             sck_en<=1;
                                             data_cnt<=data_cnt+1;
                                           end
                                       end
                                     else
                                       begin
                                         state<=state;
                                         sck_en<=1;
                                         data_cnt<=data_cnt;
                                       end
                                     end      
                           endcase
                         end

        STATE_sck_over_buff : begin
                                if(sck_buff_time_cnt==sck_buff_time_tot-1)
                                  begin
                                    state<=state;
                                    cs<=1;
                                  end
                                else
                                  begin
                                    state<=state;
                                    sck_buff_time_cnt<=sck_buff_time_cnt+1;
                                  end        
                              end
      endcase
    end
  else
    begin
      state<=STATE_cs_buff;
      cs_buff_time_cnt<=0;
      sck_buff_time_cnt<=0;
      cs<=1;
      sck_en<=0;
      data_cnt<=0;
    end
end
/************************************************************************************************/



/*******************************************产生sck信号*******************************************/
generate
  if(N%2==0)
    begin
      reg [((((N/2-1)&(N/2-1-1))==0)?$clog2(N/2-1):($clog2(N/2-1)-1)):0] clk_cnt;
      reg reg_sck;
      always@(posedge clk or negedge rst_n)
      begin
        if(!rst_n)
          begin
            clk_cnt<=0;
            reg_sck<=cpol;
          end
        else if(sck_en)
          begin
            if(clk_cnt==N/2-1)
              begin
                clk_cnt<=0;
                reg_sck<=!reg_sck;
              end
            else
              begin
                clk_cnt<=clk_cnt+1;
                reg_sck<=reg_sck;
              end
          end
        else
          begin
            clk_cnt<=0;
            reg_sck<=cpol;
          end
      end
      assign sck=reg_sck;
    end
  else
    begin
      reg [((((N-1)&(N-1-1))==0)?$clog2(N-1):($clog2(N-1)-1)):0] clk_cnt;
      reg clk_p;
      reg clk_n;
      always@(posedge clk or negedge rst_n)
      begin
        if(!rst_n)
          clk_cnt<=0;
        else if(sck_en)
          begin
            if(clk_cnt==N-1)
              clk_cnt<=0;
            else
              clk_cnt<=clk_cnt+1;
          end
        else
          clk_cnt<=0;
      end
      always@(posedge clk or negedge rst_n)
      begin
        if(!rst_n)
          clk_p<=cpol;
        else if(sck_en)
          begin
            if((clk_cnt==(N-1)/2)||(clk_cnt==(N-1)))
              clk_p<=~clk_p;
            else
              clk_p<=clk_p;
          end
        else
          clk_p<=cpol;
      end
      always@(negedge clk or negedge rst_n)
      begin
        if(!rst_n)
          clk_n<=cpol;
        else if(sck_en)
          begin
            if((clk_cnt==(N-1)/2)||(clk_cnt==(N-1)))
              clk_n<=~clk_n;
            else
              clk_n<=clk_n;
          end
        else
          clk_n<=cpol;
      end
      assign sck=cpol?(clk_p&&clk_n):(clk_p||clk_n);
    end
endgenerate
/************************************************************************************************/

endmodule