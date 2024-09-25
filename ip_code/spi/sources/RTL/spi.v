/*************************************************************/
//function: spi master顶层文件
//Author  : WangYuxiao
//Email   : wyxee2000@163.com
//Data    : 2023.09.17
//Version : V 1.0
/*************************************************************/
`timescale 1 ns / 1 ps

module spi (clk,rst_n,soft_rst_n,s_axis_tdata,s_axis_tvalid,s_axis_tready,m_axis_tready,m_axis_tdata,m_axis_tvalid,cpol,cpha,w_r_mode,wr_width,rd_width,rd_target_num,sdio,miso,mosi,cs,sck,wr_data_num);
/*******************************************工作参数设置******************************************/
parameter system_clk=50_000000;  /*定义系统时钟频率(Hz)*/
parameter spi_rate=5_000000;     /*定义SPI速率(bps)*/
parameter cs_buff_time=10;       /*cs在下降沿前稳定保持高电平的缓冲时间(unit:一个数据长度)*/
parameter sck_buff_time=4;       /*cs拉低-sck启动/sck停止-cs拉高 之间的缓冲时间(unit:一个数据长度)*/
parameter mode="4 Wire";         /*mode="3 Wire"时,为三线模式; mode="4 Wire"时,为四线模式*/
/************************************************************************************************/
input clk;                  /*系统时钟*/
input rst_n;                /*低电平异步复位信号*/
input soft_rst_n;           /*低电平异步复位信号(软复位)*/

input [31:0] s_axis_tdata;  /*输入数据(spi待发送数据)*/
input s_axis_tvalid;        /*输入数据有效标志,高电平有效*/
output s_axis_tready;       /*向上游模块发送读请求或读确认信号,高电平有效*/
input m_axis_tready;        /*下游模块传来的读请求或读确认信号,高电平有效*/
output [31:0] m_axis_tdata; /*输出数据(spi已接收数据)*/
output m_axis_tvalid;       /*输出数据有效标志,高电平有效*/

input cpol;                 /*时钟空闲态:cpol=0时,空闲为低; cpol=1时,空闲为高*/
input cpha;                 /*时钟相位:cpha=0时,在奇数个时钟边沿采样; cpha=1时,在偶数个时钟边沿采样*/
input [1:0] w_r_mode;       /*00-只读模式; 01-只写模式; 10-指令控读模式*/
input [5:0] wr_width;       /*本次SPI写传输位宽(最大支持32bit)*/
input [5:0] rd_width;       /*本次SPI读传输位宽(最大支持32bit)*/
input [15:0] rd_target_num; /*本次SPI读取的目标数据量*/

inout sdio;                 /*三线spi数据接口*/
input miso;                 /*spi master-miso*/
output mosi;                /*spi master-mosi*/
output cs;                  /*spi master-cs*/
output sck;                 /*spi master-sck*/

output [15:0] wr_data_num;  /*只写模式下spi已发送数据的总量*/



/************************************************************************************************/
generate
if(mode=="3 Wire") /*三线模式*/
begin  
  wire U1_en;
  wire U1_cs;
  wire U1_sck;
  wire tx_en;
  wire rx_en;
  wire real_rst_n;
  wire output_en;
  wire rx_in;
  wire tx_out;

  assign U1_en=(w_r_mode==0)?rx_en:tx_en;
  assign real_rst_n=rst_n&&soft_rst_n;

  IOBUF #(
      .DRIVE(12),
      .IBUF_LOW_PWR("TRUE"),
      .IOSTANDARD("DEFAULT"),
      .SLEW("SLOW")
   ) IOBUF_inst (
      .O(rx_in),     // Buffer output
      .IO(sdio),     // Buffer inout port (connect directly to top-level port)
      .I(tx_out),    // Buffer input
      .T(~output_en) // 3-state enable input, high=input, low=output
   );

  spi_cs_sck #(.system_clk(system_clk),
               .spi_rate(spi_rate),
               .cs_buff_time(cs_buff_time),
               .sck_buff_time(sck_buff_time)
              ) U1 (.clk(clk),
                    .rst_n(real_rst_n),
                    .en(U1_en),
                    .cpol(cpol),
                    .cpha(cpha),
                    .w_r_mode(w_r_mode),
                    .wr_width(wr_width),
                    .rd_width(rd_width),
                    .cs(U1_cs),
                    .sck(U1_sck)
                   );

  cs_sck_delay #(.system_clk(system_clk),
                 .spi_rate(spi_rate)
                ) U2 (.clk(clk),
                      .rst_n(real_rst_n),
                      .cpol(cpol),
                      .cpha(cpha),
                      .cs_in(U1_cs),
                      .sck_in(U1_sck),
                      .cs_out(cs),
                      .sck_out(sck)
                     );

  spi_tx #(.system_clk(system_clk),
           .spi_rate(spi_rate)
          ) U3 (.clk(clk),
                .rst_n(real_rst_n),
                .cs(U1_cs),
                .sck(U1_sck),
                .cpol(cpol),
                .cpha(cpha),
                .w_r_mode(w_r_mode),
                .wr_width(wr_width),
                .rd_width(rd_width),
                .s_axis_tdata(s_axis_tdata),
                .s_axis_tvalid(s_axis_tvalid),
                .s_axis_tready(s_axis_tready),
                .cs_sck_en(tx_en),
                .mosi(tx_out),
                .output_en(output_en),
                .wr_data_num(wr_data_num)
                );

  spi_rx U4(.clk(clk),
            .rst_n(real_rst_n),
            .cs(cs),
            .sck(sck),
            .cpol(cpol),
            .cpha(cpha),
            .w_r_mode(w_r_mode),
            .wr_width(wr_width),
            .rd_width(rd_width),
            .rd_target_num(rd_target_num),
            .miso(rx_in),
            .m_axis_tready(m_axis_tready),
            .m_axis_tdata(m_axis_tdata),
            .m_axis_tvalid(m_axis_tvalid),
            .cs_sck_en(rx_en)
            );
end
else /*四线模式*/
begin
  wire U1_en;
  wire U1_cs;
  wire U1_sck;
  wire tx_en;
  wire rx_en;
  wire real_rst_n;

  assign U1_en=(w_r_mode==0)?rx_en:tx_en;
  assign real_rst_n=rst_n&&soft_rst_n;

  spi_cs_sck #(.system_clk(system_clk),
               .spi_rate(spi_rate),
               .cs_buff_time(cs_buff_time),
               .sck_buff_time(sck_buff_time)
              ) U1 (.clk(clk),
                    .rst_n(real_rst_n),
                    .en(U1_en),
                    .cpol(cpol),
                    .cpha(cpha),
                    .w_r_mode(w_r_mode),
                    .wr_width(wr_width),
                    .rd_width(rd_width),
                    .cs(U1_cs),
                    .sck(U1_sck)
                   );

  cs_sck_delay #(.system_clk(system_clk),
                 .spi_rate(spi_rate)
                ) U2 (.clk(clk),
                      .rst_n(real_rst_n),
                      .cpol(cpol),
                      .cpha(cpha),
                      .cs_in(U1_cs),
                      .sck_in(U1_sck),
                      .cs_out(cs),
                      .sck_out(sck)
                     );

  spi_tx #(.system_clk(system_clk),
           .spi_rate(spi_rate)
          ) U3 (.clk(clk),
                .rst_n(real_rst_n),
                .cs(U1_cs),
                .sck(U1_sck),
                .cpol(cpol),
                .cpha(cpha),
                .w_r_mode(w_r_mode),
                .wr_width(wr_width),
                .rd_width(rd_width),
                .s_axis_tdata(s_axis_tdata),
                .s_axis_tvalid(s_axis_tvalid),
                .s_axis_tready(s_axis_tready),
                .cs_sck_en(tx_en),
                .mosi(mosi),
                .output_en(),
                .wr_data_num(wr_data_num)
                );

  spi_rx U4(.clk(clk),
            .rst_n(real_rst_n),
            .cs(cs),
            .sck(sck),
            .cpol(cpol),
            .cpha(cpha),
            .w_r_mode(w_r_mode),
            .wr_width(wr_width),
            .rd_width(rd_width),
            .rd_target_num(rd_target_num),
            .miso(miso),
            .m_axis_tready(m_axis_tready),
            .m_axis_tdata(m_axis_tdata),
            .m_axis_tvalid(m_axis_tvalid),
            .cs_sck_en(rx_en)
            );
end
endgenerate
/************************************************************************************************/

endmodule