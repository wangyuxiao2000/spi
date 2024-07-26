/*************************************************************/
//function: 延时模块
//Author  : WangYuxiao
//Email   : wyxee2000@163.com
//Data    : 2023.09.19
//Version : V 1.0
/*************************************************************/
`timescale 1 ns / 1 ns

module cs_sck_delay (clk,rst_n,cpol,cpha,cs_in,sck_in,cs_out,sck_out);
/*******************************************工作参数设置******************************************/
parameter system_clk=50_000000;    /*定义系统时钟频率(Hz)*/
parameter spi_rate=5_000000;       /*定义SPI速率(bps)*/
localparam N=((system_clk/spi_rate)<4)?4:(system_clk/spi_rate); /*计算分频系数(至少为4)*/
/************************************************************************************************/
input clk;        /*系统时钟*/
input rst_n;      /*低电平异步复位信号*/
input cpol;       /*时钟空闲态:cpol=0时,空闲为低; cpol=1时,空闲为高*/
input cpha;       /*时钟相位:cpha=0时,在奇数个时钟边沿采样; cpha=1时,在偶数个时钟边沿采样*/
input cs_in;      /*spi_cs_sck模块产生的cs信号*/
input sck_in;     /*spi_cs_sck模块产生的sck信号*/
output cs_out;    /*延迟后的cs信号*/
output sck_out;   /*延迟后的sck信号*/



/******************************************对信号进行延迟*****************************************/
generate
  if(N%2==0) /*将cs和sck延后一个系统时钟*/
    begin
      reg cs_reg;
      reg sck_reg;
      always@(posedge clk)
      begin
        cs_reg<=cs_in;
        sck_reg<=sck_in;
      end
      assign cs_out=cs_reg;
      assign sck_out=sck_reg;
    end
  else
    begin
        reg [1:0] cnt;
        reg sel;
        reg sck_reg_p;
        reg sck_reg_n;
        reg sck_result;
        reg cs_reg_p;
        reg cs_reg_n;
        reg cs_result;
        always@(posedge clk or negedge rst_n)
        begin
          if(!rst_n)
            begin
              sel<=0;
              cnt<=0;
            end
          else
            begin
              case({cpol,cpha})
                2'b00,2'b01 : begin
                                if(sck_in)
                                  begin
                                    if(cnt==2)
                                      begin
                                        cnt<=cnt;
                                        sel<=1;
                                      end
                                    else
                                      begin
                                        cnt<=cnt+1;
                                        sel<=0;
                                      end
                                  end
                                else
                                  begin
                                    cnt<=0;
                                    sel<=0;
                                  end
                              end
                2'b10,2'b11 : begin
                                if(!sck_in)
                                  begin
                                    if(cnt==2)
                                      begin
                                        cnt<=cnt;
                                        sel<=1;
                                      end
                                    else
                                      begin
                                        cnt<=cnt+1;
                                        sel<=0;
                                      end
                                  end
                                else
                                  begin
                                    cnt<=0;
                                    sel<=0;
                                  end
                              end
              endcase
            end
        end
        always@(posedge clk)
        begin
          cs_reg_p<=cs_in;
          sck_reg_p<=sck_in;
        end
        always@(negedge clk)
        begin
          cs_reg_n<=cs_in;
          sck_reg_n<=sck_in;
        end
        always@(*)
        begin
          case({cpol,cpha})
            2'b00,2'b11 : sck_result=sel?(sck_reg_p||sck_reg_n):(sck_reg_p&&sck_reg_n);
            2'b01,2'b10 : sck_result=sel?(sck_reg_p&&sck_reg_n):(sck_reg_p||sck_reg_n);
          endcase
        end
        always@(*)
        begin
          case({cpol,cpha})
            2'b00,2'b10 : cs_result=cs_reg_p;
            2'b01,2'b11 : cs_result=cs_reg_n;
          endcase
        end
        assign cs_out=cs_result;
        assign sck_out=sck_result;
    end
endgenerate
/************************************************************************************************/

endmodule