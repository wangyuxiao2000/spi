#pragma once

#include <cstdint>
#include <ap_int.h>
#include <ap_axi_sdata.h>
#include <hls_stream.h>

void dma_grabber(
    hls::stream<ap_axiu<32, 0, 0, 0>>& is,
    hls::stream<ap_axiu<32, 0, 0, 0>>& os,
    ap_uint<16>& data_num,
    const ap_uint<1>& en,
    const ap_uint<16>& size
);
