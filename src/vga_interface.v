`timescale 1ns / 1ps

module vga_interface(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        empty_fifo,
    input  wire [15:0] din,
    output wire        clk_vga,
    output reg         rd_en,
    output reg  [4:0]  vga_out_r,
    output reg  [5:0]  vga_out_g,
    output reg  [4:0]  vga_out_b,
    output wire        vga_out_vs,
    output wire        vga_out_hs,
    output wire        video_on
);

localparam delay   = 2'd0,
           idle    = 2'd1,
           display = 2'd2;

reg  [1:0]  state_q, state_d;
wire [11:0] pixel_x, pixel_y;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state_q <= delay;
    else        state_q <= state_d;
end

always @* begin
    state_d   = state_q;
    rd_en     = 1'b0;
    vga_out_r = 5'd0;
    vga_out_g = 6'd0;
    vga_out_b = 5'd0;
    
    case (state_q)
        delay: begin
            if (pixel_x == 1 && pixel_y == 1)
                state_d = idle;
        end

        idle: begin
            if (pixel_x == 1 && pixel_y == 0 && !empty_fifo) begin
                vga_out_r = din[15:11];
                vga_out_g = din[10:5];
                vga_out_b = din[4:0];
                rd_en     = 1'b1;
                state_d   = display;
            end
        end

        display: begin
            if (pixel_x >= 1 && pixel_x <= 640 && pixel_y < 480) begin
                vga_out_r = din[15:11];
                vga_out_g = din[10:5];
                vga_out_b = din[4:0];
                rd_en     = 1'b1;
            end
            if (pixel_y >= 480 && pixel_x == 0)
                state_d = idle;
        end

        default: state_d = delay;
    endcase
end

assign clk_vga = clk;

vga_core m0 (
    .clk     (clk),
    .rst_n   (rst_n),
    .hsync   (vga_out_hs),
    .vsync   (vga_out_vs),
    .video_on(video_on),
    .pixel_x (pixel_x),
    .pixel_y (pixel_y)
);

endmodule