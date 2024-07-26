#include "dma_grabber.h"

void dma_grabber(
    hls::stream<ap_axiu<32, 0, 0, 0>>& is,
    hls::stream<ap_axiu<32, 0, 0, 0>>& os,
    ap_uint<16>& data_num,
    const ap_uint<1>& en,
    const ap_uint<16>& size
)
{
#pragma HLS PIPELINE II=1 style=flp
#pragma HLS INTERFACE ap_ctrl_none port = return
#pragma HLS INTERFACE axis port = is
#pragma HLS INTERFACE axis port = os
#pragma HLS INTERFACE ap_none register port = data_num
#pragma HLS stable variable = data_num
#pragma HLS INTERFACE s_axilite port = en   /*offset = 0x10*/
#pragma HLS INTERFACE s_axilite port = size /*offset = 0x18*/

    static ap_uint<1> _en = 0;
    static ap_uint<1> _start = 0;
    static ap_uint<16> _size = 0;
    static ap_uint<16> _cnt = 0;
    static ap_uint<16> _wait_time = 0;
#pragma hls reset variable = _en
#pragma hls reset variable = _start
#pragma hls reset variable = _size
#pragma hls reset variable = _cnt
#pragma hls reset variable = _wait_time

    ap_axiu<32, 0, 0, 0> in;

    if(!_start)
    {
        if (!_en && en) /*en上升沿触发一次抓取*/
        {
            _start = 1;
            _size = size;
            _cnt = 0;
            _wait_time = 0;
        }
        _en = en;
    }
    else
    {
        if(!is.empty())
        {
            in = is.read();
            _cnt = _cnt + 1;
            _wait_time = 0;
            in.last = (_cnt == _size) ? 1 : 0;
            os << in;
            _start = !in.last;
        }
        else /*进行超时等待,防止因前级数据不足导致PS端DMA驱动卡死*/
        {
            _wait_time = _wait_time + 1;
            if(_wait_time == 100)
            {
                in.last = 1;
                in.keep = ap_uint<4>(0xF)(3,0);
                in.strb = ap_uint<4>(0xF)(3,0);
                os << in;
                _start = 0;
            }
        }
    }
    data_num = _cnt;
}