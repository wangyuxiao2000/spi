#pragma once

#include <ap_int.h>
#include <hls_stream.h>

void spi_regs(
    // regs
    const ap_uint<1>& soft_rst_n,       /*软复位信号(低电平有效)*/
    const ap_uint<7>& chip,             /*片选信号(最大支持64片从机)*/
    const ap_uint<1>& cpol,             /*时钟空闲态:cpol=0时,空闲为低; cpol=1时,空闲为高*/
    const ap_uint<1>& cpha,             /*时钟相位:cpha=0时,在奇数个时钟边沿采样; cpha=1时,在偶数个时钟边沿采样*/
    const ap_uint<2>& w_r_mode,         /*00-只读模式; 01-只写模式; 10-指令控读模式; 11-保留模式*/
    const ap_uint<6>& wr_width,         /*本次SPI写传输位宽(最大支持32bit)*/
    const ap_uint<32>& wr_data,         /*SPI待发送数据*/
    const ap_uint<6>& rd_width,         /*本次SPI读传输位宽(最大支持32bit)*/
    const ap_uint<16>& rd_target_num,   /*本次SPI读取的目标数据量*/
    ap_uint<1>& wr_done,                /*SPI写完成标志*/
    ap_uint<1>& rd_done,                /*SPI读完成标志*/
    ap_uint<32>& rd_data,               /*SPI已读回数据*/

    // ports
    ap_uint<1>& soft_rst_n_out,
    ap_uint<7>& chip_out,
    ap_uint<1>& cpol_out,
    ap_uint<1>& cpha_out,
    ap_uint<2>& w_r_mode_out,
    ap_uint<6>& wr_width_out,
    ap_uint<6>& rd_width_out,
    ap_uint<16>& rd_target_num_out,
    ap_uint<1>& wr_data_num_in,
    ap_uint<1>& batch_en,
    hls::stream<ap_uint<32>>& is,
    hls::stream<ap_uint<32>>& os
);
