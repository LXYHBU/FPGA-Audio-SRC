module top(
    input        Clk,
    input        Rst_n,
    input        din,
    output       SCK_1808,//11.2896M(实际11.288) 主时钟
    output       BCK_1808,//2.8224M(实际2.822M)  位同步时钟
    output       LRC_1808,//44.1K(实际44.09K)    帧同步时钟

    output       BCK_5102,//3.072M(实际3.0729M)  位同步时钟
    output       LCK_5102,//48K(实际48.01K)      帧同步时钟
    output       dout
);
//////////////////////////////////参数定义////////////////////////////////
//inst_MMCM
wire       BCK_5102_10b;
wire       locked;
wire       Clk_48M;
//inst_divider
wire       Clk_44_1K;
wire       Clk_48K;

//inst_ROM_FS_44_1K用于仿真
/*
reg  [8:0]  addra_ROM_1;
wire [15:0] douta_ROM_1;
wire       rsta_busy;*/
//线性插值
wire signed [15:0]data_out_fir;
//PCM1808
wire signed [15:0]pcm_data;
wire signed [15:0]pcm_data_boosted; // 放大后的数据
//assign pcm_data_boosted = pcm_data <<< 1;
wire data_valid;

//////////////////////////////////IP核实例化////////////////////////////////
MMCM_1 inst_MMCM_1 
(
    .clk_out1(SCK_1808),    // 11.2896M(实际11.288M)
    .clk_out2(BCK_5102_10b),// 30.72M(实际30.729M)
    .clk_out3(Clk_48M),     // 48M(实际48.098M)
    .resetn(Rst_n),         // input resetn
    .locked(locked),        // output locked
    .clk_in1(Clk)           // input clk_in1
);   
/*
ROM_1 inst_ROM_FS_44_1K (
    .clka(Clk_44_1K),        // input wire clka
    .rsta(!Rst_n),            // input wire rsta
    .addra(addra_ROM_1),           // input wire [8 : 0] addra
    .douta(douta_ROM_1),           // output wire [9 : 0] douta
    .rsta_busy(rsta_busy)    // output wire rsta_busy
);   */
//////////////////////////////////分频模块////////////////////////////////
divider inst_divider_0(//输入11.2896M，输出2.8224M 50%
    .clk_in(SCK_1808),      
    .Rst_n(Rst_n),      
    .div_ratio(16'd4),  
    .duty_cycle(16'd2),  
    .clk_out(BCK_1808)      
);
divider inst_divider_1(//输入2.8224M，输出44.1K 50%
    .clk_in(BCK_1808),      
    .Rst_n(Rst_n),      
    .div_ratio(16'd64),  
    .duty_cycle(16'd32),  
    .clk_out(LRC_1808)      
);
assign Clk_44_1K=LRC_1808;
divider inst_divider_2(//输入30.72M，输出3.072M 50%
    .clk_in(BCK_5102_10b),      
    .Rst_n(Rst_n),      
    .div_ratio(16'd10),  
    .duty_cycle(16'd5),  
    .clk_out(BCK_5102)      
);
divider inst_divider_3(//输入3.072M，输出48K 50%
    .clk_in(BCK_5102),      
    .Rst_n(Rst_n),      
    .div_ratio(16'd64),  
    .duty_cycle(16'd32),  
    .clk_out(LCK_5102)      
);
assign Clk_48K=LCK_5102;
//////////////////////////////////线性插值////////////////////////////////
Linear_interpolation inst_Linear_interpolation (
    .Clk_48M(Clk_48M),
    .Clk_44_1K(Clk_44_1K),
    .Clk_48K(Clk_48K),
    .Rst_n(Rst_n),
    //.data_in(douta_ROM_1),
    .data_in(pcm_data),
    .data_out(data_out_fir)
);
/*
//////////////////////////////////ROM 控制////////////////////////////////
always @(posedge Clk_44_1K or negedge Rst_n) begin
    if(!Rst_n)
        addra_ROM_1<=9'd0;
    else begin
        if(addra_ROM_1==440)
            addra_ROM_1<=9'd0;
        else addra_ROM_1<=addra_ROM_1+1'd1; 
    end
end
*/
//////////////////////////////////PCM1808(AD)////////////////////////////////
pcm1808_driver inst_1808(
    .Rst_n(Rst_n),
    .din(din),
    .SCK(SCK_1808),
    .BCK(BCK_1808),
    .LRC(LRC_1808),
    .pcm_data(pcm_data),
    .data_valid(data_valid)
);
//////////////////////////////////PCM5102(DA)////////////////////////////////
PCM5102_driver inst_pcm5102 (
    .rst_n(Rst_n),
    .bclk(BCK_5102),
    .lrck(LCK_5102),
    .din_vld(1'b1),              // 持续输出
    .din_data(data_out_fir),     // 输入正弦波
    .dout(dout)
);
endmodule
