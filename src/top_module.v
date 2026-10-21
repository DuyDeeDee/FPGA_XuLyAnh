`timescale 1ns / 1ps

module top_module(
    input  wire        clk,       // 50MHz board clock
    input  wire        rst_n,
    input  wire [3:0]  key,       // key[1:0]: brightness, key[3:2]: contrast
    
    input  wire [10:1]  SW,        // [THÊM MỚI] Dùng 2 Switch để chọn chế độ xử lý ảnh

    // Camera pinouts
    input  wire        cmos_pclk, cmos_href, cmos_vsync,
    input  wire [7:0]  cmos_db,
    inout              cmos_sda, cmos_scl,
    output wire        cmos_rst_n, cmos_pwdn, cmos_xclk,

    // Debugging
    output wire [3:0]  led,
    output wire [3:0]  LEDG,      // LED xanh: debug camera signals

    // SDRAM
    output wire        sdram_clk,
    output wire        sdram_cke,
    output wire        sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n,
    output wire [12:0] sdram_addr,
    output wire [1:0]  sdram_ba,
    output wire [1:0]  sdram_dqm,
    inout  wire [15:0] sdram_dq,

    // VGA output (10-bit DE2-70)
    output wire [9:0]  vga_out_r,
    output wire [9:0]  vga_out_g,
    output wire [9:0]  vga_out_b,
    output wire        vga_out_vs, vga_out_hs,
    output wire        vga_clk, vga_blank_n, vga_sync_n
);

wire        clk_sdram;
wire        clk_sdram_chip;
wire        clk_25mhz;

wire        f2s_data_valid;         
wire [9:0]  w_camera_data_count;
wire [9:0]  data_count_r;
wire [15:0] dout, din;
wire        empty_fifo;
wire        rd_en;

wire [9:0]  w_sdram_data_count = SW[6] ? 10'd0 : w_camera_data_count;

wire clk_vga;
assign clk_vga = clk_25mhz;

assign vga_clk     = clk_25mhz;
assign vga_sync_n  = 1'b0;

// Wires hứng dữ liệu GỐC từ VGA FIFO
wire [4:0]  w_vga_r_orig;
wire [5:0]  w_vga_g_orig;
wire [4:0]  w_vga_b_orig;
wire        w_video_on;

// Wires chứa dữ liệu SAU KHI ĐÃ XỬ LÝ ẢNH
wire [4:0]  w_vga_r_proc;
wire [5:0]  w_vga_g_proc;
wire [4:0]  w_vga_b_proc;

// Đệm bit xuất ra chuẩn 10-bit của DAC mạch (Sử dụng dữ liệu ĐÃ XỬ LÝ)
assign vga_out_r   = {w_vga_r_proc, 5'b00000};
assign vga_out_g   = {w_vga_g_proc, 4'b0000};
assign vga_out_b   = {w_vga_b_proc, 5'b00000};
assign vga_blank_n = w_video_on; 

pll_main m3 (
    .inclk0 (clk),
    .c0     (clk_sdram),       
    .c1     (clk_sdram_chip),  
    .c2     (clk_25mhz)        
);
assign sdram_clk = clk_sdram_chip;

camera_interface m0 (
    .clk          (clk_25mhz),
    .clk_100      (clk_sdram),
    .rst_n        (rst_n),
    .key          (key),
	 .sw_flip      (SW[4:3]),
	 .rd_en        (f2s_data_valid),         // [TRẢ VỀ NHƯ CŨ] 
    .data_count_r (w_camera_data_count),
    .dout         (dout),
    .cmos_pclk    (cmos_pclk),
    .cmos_href    (cmos_href),
    .cmos_vsync   (cmos_vsync),
    .cmos_db      (cmos_db),
    .cmos_sda     (cmos_sda),
    .cmos_scl     (cmos_scl),
    .cmos_rst_n   (cmos_rst_n),
    .cmos_pwdn    (cmos_pwdn),
    .cmos_xclk    (cmos_xclk),
    .led          (led)
);

sdram_interface m1 (
    .clk           (clk_sdram),
    .rst_n         (rst_n),
    .cmos_vsync    (cmos_vsync),      
    .vga_vsync     (vga_out_vs),      
    .clk_vga       (clk_vga),
    .rd_en         (rd_en),
    .data_count_r  (w_sdram_data_count),    // [SỬA] Cắm dây đã "hack" vào SDRAM
    .f2s_data      (dout),
    .f2s_data_valid(f2s_data_valid),
    .empty_fifo    (empty_fifo),
    .dout          (din),
    .sdram_cke     (sdram_cke),
    .sdram_cs_n    (sdram_cs_n),
    .sdram_ras_n   (sdram_ras_n),
    .sdram_cas_n   (sdram_cas_n),
    .sdram_we_n    (sdram_we_n),
    .sdram_addr    (sdram_addr),
    .sdram_ba      (sdram_ba),
    .sdram_dqm     (sdram_dqm),
    .sdram_dq      (sdram_dq)
);

// Khối điều khiển quét xuất ảnh
vga_interface m2 (
    .clk        (clk_25mhz),  
    .rst_n      (rst_n),
    .empty_fifo (empty_fifo),
    .din        (din),
    .clk_vga    (clk_vga),    
    .rd_en      (rd_en),
    
    // Xuất ra dữ liệu gốc
    .vga_out_r  (w_vga_r_orig),
    .vga_out_g  (w_vga_g_orig),
    .vga_out_b  (w_vga_b_orig),
    .vga_out_vs (vga_out_vs),
    .vga_out_hs (vga_out_hs),
    .video_on   (w_video_on)
);

// [THÊM MỚI] Module Xử Lý Ảnh Thời Gian Thực
image_processing ip_inst (
    .clk   (clk_25mhz),
    .mode  (SW[2:1]),  	 // Lấy 2 Switch làm chế độ điều khiển
	 .split_en (SW[5]),            // [THÊM] Cắm SW5 vào chia màn hình
	 .detect_en(SW[8]),
	 .color_sel (SW[10:9]),
    .video_on (w_video_on),
    .r_in  (w_vga_r_orig),     // Lấy dữ liệu màu gốc đi vào
    .g_in  (w_vga_g_orig),
    .b_in  (w_vga_b_orig),
    .r_out (w_vga_r_proc),     // Nhả dữ liệu màu đã xử lý đi ra
    .g_out (w_vga_g_proc),
    .b_out (w_vga_b_proc)
);

reg vsync_toggle = 1'b0;
reg href_toggle  = 1'b0;
reg pclk_toggle  = 1'b0;

always @(posedge cmos_vsync) vsync_toggle <= ~vsync_toggle;
always @(posedge cmos_href)  href_toggle  <= ~href_toggle;
always @(posedge cmos_pclk)  pclk_toggle  <= ~pclk_toggle;

assign LEDG[3] = vsync_toggle;
assign LEDG[2] = cmos_vsync;
assign LEDG[1] = href_toggle;
assign LEDG[0] = pclk_toggle;

endmodule