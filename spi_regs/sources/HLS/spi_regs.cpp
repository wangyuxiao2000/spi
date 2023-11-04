#include "spi_regs.h"

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
)
{
#pragma HLS PIPELINE II=1 style=flp
#pragma HLS INTERFACE ap_ctrl_none port = return
#pragma HLS INTERFACE s_axilite port = soft_rst_n
#pragma HLS INTERFACE s_axilite port = chip
#pragma HLS INTERFACE s_axilite port = cpol
#pragma HLS INTERFACE s_axilite port = cpha
#pragma HLS INTERFACE s_axilite port = w_r_mode
#pragma HLS INTERFACE s_axilite port = wr_width
#pragma HLS INTERFACE s_axilite port = wr_data
#pragma HLS INTERFACE s_axilite port = rd_width
#pragma HLS INTERFACE s_axilite port = rd_target_num
#pragma HLS INTERFACE ap_none port = wr_done
#pragma HLS INTERFACE s_axilite port = wr_done
#pragma HLS INTERFACE ap_none port = rd_done
#pragma HLS INTERFACE s_axilite port = rd_done
#pragma HLS INTERFACE ap_none port = rd_data
#pragma HLS INTERFACE s_axilite port = rd_data
#pragma HLS INTERFACE ap_none port = soft_rst_n_out
#pragma HLS stable variable = soft_rst_n_out
#pragma HLS INTERFACE ap_none port = chip_out
#pragma HLS stable variable = chip_out
#pragma HLS INTERFACE ap_none port = cpol_out
#pragma HLS stable variable = cpol_out
#pragma HLS INTERFACE ap_none port = cpha_out
#pragma HLS stable variable = cpha_out
#pragma HLS INTERFACE ap_none port = w_r_mode_out
#pragma HLS stable variable = w_r_mode_out
#pragma HLS INTERFACE ap_none port = wr_width_out
#pragma HLS stable variable = wr_width_out
#pragma HLS INTERFACE ap_none port = rd_width_out
#pragma HLS stable variable = rd_width_out
#pragma HLS INTERFACE ap_none port = rd_target_num_out
#pragma HLS stable variable = rd_target_num_out
#pragma HLS INTERFACE ap_stable port = wr_data_num_in
#pragma HLS stable variable = wr_data_num_in
#pragma HLS INTERFACE ap_stable port = batch_en
#pragma HLS stable variable = batch_en
#pragma HLS INTERFACE axis register port = is
#pragma HLS INTERFACE axis register port = os

    static ap_uint<1> _wr_en = 1;
    static ap_uint<1> _wr_done = 0;
    static ap_uint<1> _rd_done = 0;
#pragma hls reset variable = _wr_en
#pragma hls reset variable = _wr_done
#pragma hls reset variable = _rd_done

    soft_rst_n_out = soft_rst_n;
    chip_out = chip;
    cpol_out = cpol;
    cpha_out = cpha;
    w_r_mode_out = w_r_mode;
    wr_width_out = wr_width;
    rd_width_out = rd_width;
    rd_target_num_out = rd_target_num;
    rd_done = _rd_done;
    wr_done = _wr_done;

    if (batch_en)
    {
        
    }
    else
    {
        if (!soft_rst_n_out)
        {
            _wr_en = 1;
            _wr_done = 0;
            _rd_done = 0;
        }
        else
        {
            switch (w_r_mode_out)
            {
                case 0 : /*只读模式*/
                    if (!is.empty())
                    {
                        rd_data = is.read();
                        _rd_done = 1;
                    }
                    break;
                case 1 : /*只写模式*/
                    if (_wr_en)
                    {
                        os << wr_data;
                        _wr_en = 0;
                    }
                    if (wr_data_num_in)
                    {
                        _wr_done = 1;
                    }
                    break;
                case 2 : /*指令控读模式*/
                    if (_wr_en)
                    {
                        os << wr_data;
                        _wr_en = 0;
                    }
                    if (!is.empty())
                    {
                        rd_data = is.read();
                        _rd_done = 1;
                    }
                    break;
                default : break;
            }
        }
    }
    
}