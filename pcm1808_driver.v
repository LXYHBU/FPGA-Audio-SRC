module pcm1808_driver(
    input Rst_n,
    input din,
    input SCK,
    input BCK,
    input LRC,
    output reg [15:0] pcm_data,  // 16 位
    output reg data_valid
);
    reg [5:0]  bit_cnt;   
    reg [15:0] shift_reg; //  16 位移位寄存器
    reg        LRC_r;

    // 1. 边沿检测与计数：LRC 变化时代表新一帧开始
    always @(posedge BCK or negedge Rst_n) begin
        if(!Rst_n) begin
            LRC_r   <= 1'b0;
            bit_cnt <= 6'd0;
        end
        else begin
            LRC_r <= LRC;
            if(LRC ^ LRC_r)
                bit_cnt <= 6'd0; // 只要 LRC 跳变（进入新声道），计数器清零
            else 
                bit_cnt <= bit_cnt + 1'b1;
        end
    end

    // 2. 串转并逻辑 (截取前 16 位)
    always @(negedge BCK or negedge Rst_n) begin
        if(!Rst_n) begin
            shift_reg  <= 16'd0;
            pcm_data   <= 16'd0;
            data_valid <= 1'b0;
        end
        else begin
            data_valid <= 1'b0;
            // I2S 标准：LRC 跳变后的第 1 个 BCK 周期是空闲位
            // 第 2 个上升沿采样到 MSB (bit_cnt == 1)
            
            // 假设我们采集 LRC=0 (左声道) 或 LRC=1 (右声道)
            // 通常赛题任务 1 只需要单声道，这里以 LRC=1 为例（匹配你原代码）
            if(LRC == 1'b1) begin
                if(bit_cnt >= 6'd1 && bit_cnt <= 6'd16) begin
                    shift_reg <= {shift_reg[14:0], din}; // 移入 16 位
                end
                
                if(bit_cnt == 6'd16) begin
                    pcm_data   <= {shift_reg[14:0], din}; // 锁存 16 位结果
                    data_valid <= 1'b1; // 产生数据有效脉冲
                end
            end
        end
    end
endmodule