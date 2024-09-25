/*************************************************************/
//function: spi master接收模块
//Author  : WangYuxiao
//Email   : wyxee2000@163.com
//Data    : 2023.09.16
//Version : V 1.0
/*************************************************************/
`timescale 1 ns / 1 ps

module spi_rx (clk,rst_n,cs,sck,cpol,cpha,w_r_mode,wr_width,rd_width,rd_target_num,miso,m_axis_tready,m_axis_tdata,m_axis_tvalid,cs_sck_en);
input clk;                      /*系统时钟*/
input rst_n;                    /*低电平异步复位信号*/
input cs;                       /*cs片选信号输入*/
input sck;                      /*sck时钟输入*/
input cpol;                     /*时钟空闲态:cpol=0时,空闲为低; cpol=1时,空闲为高*/
input cpha;                     /*时钟相位:cpha=0时,在奇数个时钟边沿采样; cpha=1时,在偶数个时钟边沿采样*/
input [1:0] w_r_mode;           /*00-只读模式; 01-只写模式; 10-指令控读模式;*/
input [5:0] wr_width;           /*本次SPI写传输位宽(最大支持32bit)*/
input [5:0] rd_width;           /*本次SPI读传输位宽(最大支持32bit)*/
input [15:0] rd_target_num;     /*本次SPI读取的目标数据量*/
input miso;                     /*spi主机的miso接口输入*/
input m_axis_tready;            /*下游模块传来的读请求或读确认信号,高电平有效*/
output reg [31:0] m_axis_tdata; /*输出数据*/
output reg m_axis_tvalid;       /*输出数据有效标志,高电平有效*/
output reg cs_sck_en;           /*spi_cs_sck模块启动信号*/



/******************************************在sck边沿采样******************************************/
reg edge_sel; /*edge_sel=0,上升沿采样; edge_sel=1,下降沿采样*/
reg [63:0] data_p;
reg [63:0] data_n;
reg [6:0] data_tot;
reg [5:0] data_cnt_p;
reg [5:0] data_cnt_n;

always@(*)
begin
  case({cpol,cpha})
    2'b00,2'b11 : edge_sel=0;
    2'b01,2'b10 : edge_sel=1;
  endcase
end

always@(*)
begin
  case(w_r_mode)
    2'd0 : data_tot=rd_width;
    2'd1 : data_tot=wr_width;
    2'd2 : data_tot=wr_width+rd_width;
    default : data_tot=wr_width+rd_width;
  endcase
end

always@(posedge sck or negedge rst_n)
begin
  if(!rst_n)
    begin
      data_p<=0;
      data_cnt_p<=0;
    end
  else if((w_r_mode==0||w_r_mode==2)&&(!edge_sel))
    begin
      data_p[data_tot-1-data_cnt_p]<=miso;
      if(data_cnt_p==data_tot-1)
        data_cnt_p<=0;
      else
        data_cnt_p<=data_cnt_p+1;
    end
  else
    begin
      data_p<=0;
      data_cnt_p<=0;      
    end
end

always@(negedge sck or negedge rst_n)
begin
  if(!rst_n)
    begin
      data_n<=0;
      data_cnt_n<=0;
    end
  else if((w_r_mode==0||w_r_mode==2)&&(edge_sel))
    begin
      data_n[data_tot-1-data_cnt_n]<=miso;
      if(data_cnt_n==data_tot-1)
        data_cnt_n<=0;
      else
        data_cnt_n<=data_cnt_n+1;
    end
  else
    begin
      data_n<=0;
      data_cnt_n<=0;      
    end
end
/************************************************************************************************/



/****************************************在cs上升沿输出结果***************************************/
reg [1:0] state;
localparam STATE_init=2'b00;
localparam STATE_wait_cs=2'b01;    /*等待cs信号拉高*/
localparam STATE_data_out=2'b11;   /*等待tready信号,输出结果*/
localparam STATE_done=2'b10;       

reg cs_reg;
reg [15:0] rd_data_num;

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    cs_reg<=1;
  else
    cs_reg<=cs;
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    begin
      state<=STATE_init;
      cs_sck_en<=0;
      rd_data_num<=0;
      m_axis_tdata<=0;
      m_axis_tvalid<=0;
    end
  else if(w_r_mode==0||w_r_mode==2)
    begin
      case(state)
        STATE_init : begin
                       if(rd_data_num==rd_target_num)
                          begin
                            state<=state;
                            cs_sck_en<=0;
                          end
                       else
                         begin
                           state<=STATE_wait_cs;
                           cs_sck_en<=(w_r_mode==0)?1:0;
                         end
                     end

        STATE_wait_cs : begin
                          if(!cs_reg&&cs)
                            begin
                              state<=STATE_data_out;
                              m_axis_tdata<=edge_sel?data_n[31:0]:data_p[31:0];
                              m_axis_tvalid<=1;
                            end
                          else
                            begin
                              state<=state;
                              m_axis_tdata<=0;
                              m_axis_tvalid<=0;
                            end
                        end

        STATE_data_out : begin
                           if(m_axis_tready)
                             begin
                               state<=STATE_done;
                               m_axis_tvalid<=0;
                             end
                           else
                             begin
                               state<=state;
                               m_axis_tvalid<=1;
                             end
                         end

        STATE_done : begin
                       rd_data_num<=rd_data_num+1;
                       state<=STATE_init;
                     end
      endcase
    end
  else
    begin
      state<=STATE_init;
      cs_sck_en<=0;
      rd_data_num<=0;
      m_axis_tdata<=0;
      m_axis_tvalid<=0;      
    end
end
/************************************************************************************************/

endmodule