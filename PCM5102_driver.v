module PCM5102_driver(
    input  wire        rst_n,
    input  wire        bclk,     // 3.072MHz (或根据你的 MMCM 实际输出)
    input  wire        lrck,     // 48kHz
    input  wire        din_vld,  // 数据有效使能
    input  wire [15:0] din_data, // 已改为 16位输入数据
    output reg         dout      // 串行输出
);

    reg [31:0] shift_reg;
    reg [5:0]  bit_cnt;
    reg        lrck_d1;

    // 1. 探测 LRCK 边沿 (用于同步加载)
    always @(posedge bclk or negedge rst_n) begin
        if (!rst_n) lrck_d1 <= 1'b0;
        else        lrck_d1 <= lrck;
    end

    // 2. 位计数与移位逻辑
    always @(negedge bclk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt <= 6'd0;
            shift_reg <= 32'd0;
            dout <= 1'b0;
        end else begin
            if (lrck ^ lrck_d1) begin
                // 当 LRCK 切换瞬间，重置计数器
                bit_cnt <= 6'd0;
                dout <= 1'b0; // I2S 标准：LRCK 跳变后的第一个 BCLK 是空闲位
                
                // 加载 16 位数据到 32 位移位寄存器的高位
                if (lrck == 1'b0) 
                    // 左声道：数据占据高16位，低16位补0
                    shift_reg <= {din_data, 16'h0000}; 
                else 
                    // 右声道：目前发 0（如果是直通模式，可以改成加载右声道数据）
                    shift_reg <= 32'h00000000;
            end else begin
                bit_cnt <= bit_cnt + 1'b1;
                
                // I2S 标准移位逻辑
                if (bit_cnt < 6'd31) begin
                    dout <= shift_reg[31];
                    shift_reg <= {shift_reg[30:0], 1'b0};
                end else begin
                    dout <= 1'b0;
                end
            end
        end
    end
endmodule