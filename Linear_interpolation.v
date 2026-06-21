module Linear_interpolation(
    input Clk_48M,
    input Clk_44_1K,
    input Clk_48K,
    input Rst_n,
    input  signed [15:0]data_in,
    //input data_in_valid,//修改处
    output signed [15:0]data_out
);
//////////////////////////////////参数定义////////////////////////////////
//FIFO1
reg        fifo1_wr_en,fifo1_rd_en;
wire       fifo1_rd_valid;
wire       fifo1_full,fifo1_empty;
wire [15:0]fifo1_out;
wire       fifo1_wr_rst_busy,fifo1_rd_rst_busy;
//FIFO2
reg  [15:0]fifo2_in;
reg        fifo2_wr_en,fifo2_rd_en;
wire       fifo2_rd_valid;
wire       fifo2_full,fifo2_empty;
wire       fifo2_wr_rst_busy,fifo2_rd_rst_busy;
//线性插值算法
reg  [9:0]  cnt_48k;
reg         en_48k;
reg  signed [15:0] din_prev;
reg  signed [15:0] din_curr;
reg         data_valid;
parameter   MAX_acc =16'd65535 ;
parameter   STEP =16'd60211 ;
reg  [31:0] phase_acc;//相位累加器
reg  [31:0] phase_remain;  //余数
wire signed[31:0] k;       // 插值系数k（0~65535） k=phase_remain/65536
wire signed[31:0] k_comp;  // 1-k（0~65535）

reg  signed[15:0] interpolate_res;   // 插值结果（截位后）
wire signed[47:0] mul_prev;          // y0*(1-k)
wire signed[47:0] mul_curr;          // y1*k
wire signed[48:0] sum_temp;          // 加权和
assign k            = phase_remain;
assign k_comp       = MAX_acc - k;
assign mul_prev     = din_prev * k_comp;
assign mul_curr     = din_curr * k;
assign sum_temp     = mul_prev + mul_curr;

//////////////////////////////////IP核实例化////////////////////////////////
FIFO_1 inst_fifo_1 (
  .rst(!Rst_n),                  // input wire rst
  .wr_clk(Clk_44_1K),            // input wire wr_clk
  .rd_clk(Clk_48M),            // input wire rd_clk
  .din(data_in),                  // input wire [15 : 0] din
  .wr_en(fifo1_wr_en),              // input wire wr_en
  .rd_en(fifo1_rd_en),              // input wire rd_en
  .dout(fifo1_out),                // output wire [15 : 0] dout
  .full(fifo1_full),                // output wire full
  .empty(fifo1_empty),              // output wire empty
  .valid(fifo1_rd_valid),              // output wire valid
  .wr_rst_busy(fifo1_wr_rst_busy),  // output wire wr_rst_busy
  .rd_rst_busy(fifo1_rd_rst_busy)  // output wire rd_rst_busy
);
wire [39:0]FIR_out ;
FIFO_2 inst_fifo_2 (
  .rst(!Rst_n),                  // input wire rst
  .wr_clk(Clk_48M),            // input wire wr_clk
  .rd_clk(Clk_48K),            // input wire rd_clk
  .din(FIR_out[30:15]),                  // input wire [15 : 0] din
  .wr_en(fifo2_wr_en),              // input wire wr_en
  .rd_en(fifo2_rd_en),              // input wire rd_en
  .dout(data_out),                // output wire [15 : 0] dout
  .full(fifo2_full),                // output wire full
  .empty(fifo2_empty),              // output wire empty
  .valid(fifo2_rd_valid),              // output wire valid
  .wr_rst_busy(fifo2_wr_rst_busy),  // output wire wr_rst_busy
  .rd_rst_busy(fifo2_rd_rst_busy)  // output wire rd_rst_busy
);
//////////////////////////////////FIFO1写控制////////////////////////////////
always @(posedge Clk_44_1K or negedge Rst_n) begin
    if(!Rst_n)
        fifo1_wr_en<=1'b0;
    else if(!fifo1_full && !fifo1_wr_rst_busy)
        fifo1_wr_en<=1'b1;
    else fifo1_wr_en <= 1'b0;
end
//////////////////////////////////FIFO2读控制////////////////////////////////
always @(posedge Clk_48K or negedge Rst_n) begin
    if(!Rst_n)
        fifo2_rd_en<=1'b0;
    else if(!fifo2_empty && !fifo2_rd_rst_busy)
        fifo2_rd_en<=1'b1;
    else fifo2_rd_en <= 1'b0;
end
//使能控制
always @(posedge Clk_48M or negedge Rst_n) begin
    if(!Rst_n)begin
        cnt_48k<=10'd0;
        en_48k <=1'd0;
    end
    else begin
        if(cnt_48k==10'd999)begin
            cnt_48k<=10'd0;
            en_48k <=1'd1;
        end
        else begin
            cnt_48k<=cnt_48k+1'd1;
            en_48k <=1'd0;
        end
    end
end
//数据更新
always @(posedge Clk_48M or negedge Rst_n) begin
    if(!Rst_n) begin
        din_prev<=16'd0;
        din_curr<=16'd0;
    end
    else if(fifo1_rd_valid) begin
        din_prev<= din_curr;  // y0 = 原y1
        din_curr<= fifo1_out; // y1 = 新原始点
    end
end
reg inter_flag;
//相位累加器
always @(posedge Clk_48M or negedge Rst_n) begin
    if(!Rst_n) begin
        phase_acc<=32'd0;
        phase_remain<=32'd0;
        fifo1_rd_en<=1'd0;
        inter_flag<=1'd0;
        interpolate_res<=16'd0;
    end
    else if(en_48k)begin
        if(phase_acc + STEP>=MAX_acc) begin
            phase_acc<=phase_acc+STEP-MAX_acc;
            phase_remain<=phase_acc+STEP-MAX_acc;
            fifo1_rd_en<=1'd1;
        end
        else begin
            phase_acc<=phase_acc+STEP;
            phase_remain<=phase_acc+STEP;          
        end
        interpolate_res <= sum_temp >> 16;
        inter_flag<=1'd1;
    end
    else begin
        fifo1_rd_en<=1'd0;
        inter_flag<=1'd0;
    end
end
reg [15:0] FIR_in ;
always @(posedge Clk_48M or negedge Rst_n) begin
    if(!Rst_n)
        FIR_in<=16'd0;
    else if(inter_flag)
        FIR_in<=interpolate_res;
    else   
        FIR_in<=FIR_in;
end
//////////////////////////////////FIR////////////////////////////////
wire m_axis_data_tvalid;
//reg [15:0]FIR_out ;
FIR FIR_1 (
  .aclk(Clk_48M),                              // input wire aclk
  .s_axis_data_tvalid(en_48k),  // input wire s_axis_data_tvalid
  .s_axis_data_tready(),  // output wire s_axis_data_tready
  .s_axis_data_tdata(FIR_in),    // input wire [15 : 0] s_axis_data_tdata
  .m_axis_data_tvalid(m_axis_data_tvalid),  // output wire m_axis_data_tvalid
  .m_axis_data_tdata(FIR_out)    // output wire [39 : 0] m_axis_data_tdata
);
always @(posedge Clk_48M or negedge Rst_n) begin
    if(!Rst_n)
        fifo2_wr_en<=1'd0;
    else if(m_axis_data_tvalid)
        fifo2_wr_en<=1'd1;
    else   
        fifo2_wr_en<=1'd0;
end
endmodule