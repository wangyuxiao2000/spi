/*************************************************************/
//function: spi master发送模块
//Author  : WangYuxiao
//Email   : wyxee2000@163.com
//Data    : 2023.09.16
//Version : V 1.0
/*************************************************************/
`timescale 1 ns / 1 ns

module spi_tx (clk,rst_n,cs,sck,cpol,cpha,w_r_mode,wr_width,rd_width,s_axis_tdata,s_axis_tvalid,s_axis_tready,cs_sck_en,mosi,wr_data_num);
/*******************************************工作参数设置******************************************/
parameter system_clk=50_000000;    /*定义系统时钟频率(Hz)*/
parameter spi_rate=5_000000;       /*定义SPI速率(bps)*/
localparam N=((system_clk/spi_rate)<4)?4:(system_clk/spi_rate); /*计算分频系数(至少为4)*/
/************************************************************************************************/
input clk;                     /*系统时钟*/
input rst_n;                   /*低电平异步复位信号*/
input cs;                      /*cs片选信号输入*/
input sck;                     /*sck原始时钟输入*/
input cpol;                    /*时钟空闲态:cpol=0时,空闲为低; cpol=1时,空闲为高*/
input cpha;                    /*时钟相位:cpha=0时,在奇数个时钟边沿采样; cpha=1时,在偶数个时钟边沿采样*/
input [1:0] w_r_mode;          /*00-只读模式; 01-只写模式; 10-指令控读模式*/
input [5:0] wr_width;          /*本次SPI写传输位宽(最大支持32bit)*/
input [5:0] rd_width;          /*本次SPI读传输位宽(最大支持32bit)*/
input [31:0] s_axis_tdata;     /*输入数据*/
input s_axis_tvalid;           /*输入数据有效标志,高电平有效*/
output reg s_axis_tready;      /*向上游模块发送读请求或读确认信号,高电平有效*/
output reg cs_sck_en;          /*spi_cs_sck模块启动信号*/
output reg mosi;               /*spi主机的mosi接口输出*/
output reg [15:0] wr_data_num; /*只写模式下spi已发送数据的总量*/



/*******************************************MOSI发送数据******************************************/
reg [1:0] state;
localparam STATE_init=2'b00;       /*等待AXIS-tvalid信号的到来,启动cs_sck_en*/
localparam STATE_transfer=2'b01;   /*传输数据*/
localparam STATE_wait_cs=2'b11;    /*数据传输完成后,等待cs信号拉高,关闭cs_sck_en*/
localparam STATE_done=2'b10;       /*输出状态信号,用于告知PS端此时spi完成发送*/

reg [31:0] data_reg;
reg [4:0] data_cnt;
reg cs_reg;
reg sck_reg;
reg mosi_wait_en;
reg [((((N-1)&(N-1-1))==0)?$clog2(N-1):($clog2(N-1)-1)):0] mosi_wait_cnt;

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    begin
      cs_reg<=1;
      sck_reg<=cpol;
    end
  else
    begin
      cs_reg<=cs;
      sck_reg<=sck;
    end
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    mosi_wait_cnt<=0;
  else if(mosi_wait_en)
    begin
      if(mosi_wait_cnt==N-1)
        mosi_wait_cnt<=0;
      else
        mosi_wait_cnt<=mosi_wait_cnt+1;
    end
  else
    mosi_wait_cnt<=0;
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    begin
      state<=STATE_init;
      s_axis_tready<=0;
      data_reg<=0;
      cs_sck_en<=0;
      data_cnt<=0;
      mosi_wait_en<=0;
      mosi<=0;
      wr_data_num<=0;
    end
  else if(w_r_mode==1 || w_r_mode==2) /*1-只写模式; 2-指令控读模式*/
    begin
      case(state)
        STATE_init : begin
                       if(s_axis_tvalid&&s_axis_tready)
                         begin
                           state<=STATE_transfer;
                           s_axis_tready<=0;
                           data_reg<=s_axis_tdata;
                           cs_sck_en<=1;
                           data_cnt<=0;
                           mosi<=0;
                           mosi_wait_en<=0;
                         end
                       else
                         begin
                           state<=state;
                           s_axis_tready<=1;
                           data_reg<=0;
                           cs_sck_en<=0;
                           data_cnt<=0;
                           mosi<=0;
                           mosi_wait_en<=0;
                         end
                     end

        STATE_transfer : begin
                           case({cpol,cpha})
                             2'b00 : begin
                                       if(!sck_reg&&sck)
                                         begin
                                           if(data_cnt==wr_width-1)
                                             data_cnt<=0;
                                           else
                                             data_cnt<=data_cnt+1;
                                         end
                                       else
                                         data_cnt<=data_cnt;

                                       if(sck_reg&&!sck)
                                         begin
                                           if(data_cnt==0)
                                             begin
                                               state<=STATE_wait_cs;
                                               mosi<=0;
                                             end
                                           else
                                             begin
                                               state<=state;
                                               mosi<=data_reg[wr_width-1-data_cnt];
                                             end
                                         end
                                       else if(cs_reg&&!cs)
                                         begin
                                           state<=state;
                                           mosi<=data_reg[wr_width-1];
                                         end
                                       else
                                         begin
                                           state<=state;
                                           mosi<=mosi;
                                         end
                                     end

                             2'b01 : begin
                                       if(sck_reg&&!sck)
                                         begin
                                           if(data_cnt==wr_width-1)
                                             data_cnt<=0;
                                           else
                                             data_cnt<=data_cnt+1;
                                         end
                                       else
                                         data_cnt<=data_cnt;
                                       
                                       if(!mosi_wait_en)
                                         begin
                                           if(!sck_reg&&sck)
                                             begin
                                               state<=state;
                                               mosi<=data_reg[wr_width-1-data_cnt];
                                               if(data_cnt==wr_width-1)
                                                 mosi_wait_en<=1;
                                               else
                                                 mosi_wait_en<=0;
                                             end
                                           else
                                             begin
                                               state<=state;
                                               mosi<=mosi;
                                               mosi_wait_en<=mosi_wait_en;
                                             end
                                         end
                                       else if(cs_reg&&!cs)
                                         begin
                                           state<=state;
                                           mosi<=data_reg[wr_width-1];
                                           mosi_wait_en<=mosi_wait_en;
                                         end
                                       else
                                         begin
                                           if(mosi_wait_cnt==N-1)
                                             begin
                                               state<=STATE_wait_cs;
                                               mosi<=0;
                                               mosi_wait_en<=0;
                                             end
                                           else
                                             begin
                                               state<=state;
                                               mosi<=mosi;
                                               mosi_wait_en<=mosi_wait_en;
                                             end
                                         end
                                     end

                             2'b10 : begin
                                       if(sck_reg&&!sck)
                                         begin
                                           if(data_cnt==wr_width-1)
                                             data_cnt<=0;
                                           else
                                             data_cnt<=data_cnt+1;
                                         end
                                       else
                                         data_cnt<=data_cnt;

                                       if(!sck_reg&&sck)
                                         begin
                                           if(data_cnt==0)
                                             begin
                                               state<=STATE_wait_cs;
                                               mosi<=0;
                                             end
                                           else
                                             begin
                                               state<=state;
                                               mosi<=data_reg[wr_width-1-data_cnt];
                                             end
                                         end
                                       else if(cs_reg&&!cs)
                                         begin
                                           state<=state;
                                           mosi<=data_reg[wr_width-1];
                                         end
                                       else
                                         begin
                                           state<=state;
                                           mosi<=mosi;
                                         end
                                     end

                             2'b11 : begin
                                       if(!sck_reg&&sck)
                                         begin
                                           if(data_cnt==wr_width-1)
                                             data_cnt<=0;
                                           else
                                             data_cnt<=data_cnt+1;
                                         end
                                       else
                                         data_cnt<=data_cnt;
                                       
                                       if(!mosi_wait_en)
                                         begin
                                           if(sck_reg&&!sck)
                                             begin
                                               state<=state;
                                               mosi<=data_reg[wr_width-1-data_cnt];
                                               if(data_cnt==wr_width-1)
                                                 mosi_wait_en<=1;
                                               else
                                                 mosi_wait_en<=0;
                                             end
                                           else
                                             begin
                                               state<=state;
                                               mosi<=mosi;
                                               mosi_wait_en<=mosi_wait_en;
                                             end
                                         end
                                       else if(cs_reg&&!cs)
                                         begin
                                           state<=state;
                                           mosi<=data_reg[wr_width-1];
                                           mosi_wait_en<=mosi_wait_en;
                                         end                                         
                                       else
                                         begin
                                           if(mosi_wait_cnt==N-1)
                                             begin
                                               state<=STATE_wait_cs;
                                               mosi<=0;
                                               mosi_wait_en<=0;
                                             end
                                           else
                                             begin
                                               state<=state;
                                               mosi<=mosi;
                                               mosi_wait_en<=mosi_wait_en;
                                             end
                                         end
                                     end
                           endcase
                         end

        STATE_wait_cs : begin
                          if(!cs_reg&&cs)
                            begin
                              state<=STATE_done;
                              cs_sck_en<=0;
                            end
                          else
                            begin
                              state<=state;
                              cs_sck_en<=1;
                            end
                        end

        STATE_done : begin
                       state<=STATE_init;
                       if(w_r_mode==2'b01)
                         wr_data_num<=wr_data_num+1;
                       else
                         wr_data_num<=0;
                     end
      endcase
    end
  else
    begin
      state<=STATE_init;
      s_axis_tready<=0;
      data_reg<=0;
      cs_sck_en<=0;
      data_cnt<=0;
      mosi<=0;
      mosi_wait_en<=0;
      wr_data_num<=0;
    end
end
/************************************************************************************************/

endmodule