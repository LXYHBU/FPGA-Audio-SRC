`timescale 1ns / 1ps
module TOP_tb();
reg Clk;
reg Rst_n;
wire Clk_48K;
wire [15:0]data_out;
wire [15:0]inte_out;
initial begin
    Clk=0;
    Rst_n=1;
    #20 Rst_n=0;
    #20 Rst_n=1;
end
always #10 Clk<=~Clk;
TOP inst_top(
    .Clk(Clk),
    .clk48(Clk_48K),
    .Rst_n(Rst_n),
    .data_out(data_out),
    .inte_out(inte_out)
);
// 1. 定义文件句柄
integer file_yes_fir;
integer file_no_fir;

// 2. 打开文件
initial begin
    // "w" 表示写入模式，文件会生成在仿真工程的目录下
    file_yes_fir = $fopen("data_yes_fir_30ms.txt", "w");
    file_no_fir  = $fopen("data_no_fir_30ms.txt", "w");
    
    // 运行足够长的时间后停止，防止文件无限大
    // 根据你的仿真时间调整，比如这里是跑 20ms
    #100000000; 
    
    // 关闭文件
    $fclose(file_yes_fir);
    $fclose(file_no_fir);
    $display("Data export finished!");
    $stop; // 停止仿真
end

// 3. 抓取数据并写入
// 建议在 48kHz 时钟的上升沿抓取，因为这是你的输出采样率
always @(posedge Clk_48K) begin
    if(Rst_n) begin
        // %d 表示以十进制写入
        // 如果数据有时候是 0 或者无效，你可能需要手动延时一段时间再开始记录
        // 这里直接记录所有 48k 时钟下的数据
        $fdisplay(file_yes_fir, "%d", data_out);
        $fdisplay(file_no_fir, "%d", inte_out);
    end
end
endmodule
