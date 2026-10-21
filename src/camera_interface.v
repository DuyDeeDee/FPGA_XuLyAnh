`timescale 1ns / 1ps

module camera_interface(
    input  wire        clk,
    input  wire        clk_100,
    input  wire        rst_n,
    input  wire [3:0]  key,
	 input  wire [1:0]  sw_flip,
    input  wire        rd_en,
    output wire [9:0]  data_count_r,
    output wire [15:0] dout,
    input  wire        cmos_pclk, cmos_href, cmos_vsync,
    input  wire [7:0]  cmos_db,
    inout              cmos_sda, cmos_scl,
    output wire        cmos_rst_n, cmos_pwdn, cmos_xclk,
    output wire [3:0]  led
);

localparam idle            = 4'd0,
           start_sccb      = 4'd1,
           write_address   = 4'd2,
           write_data      = 4'd3,
           digest_loop     = 4'd4,
           delay           = 4'd5,
           wait_vsync_high = 4'd6,
           byte1           = 4'd7,
           byte2           = 4'd8,
           fifo_write      = 4'd9,
           wait_vsync_low  = 4'd10;

localparam wait_init    = 3'd0,
           sccb_idle    = 3'd1,
           sccb_address = 3'd2,
           sccb_data    = 3'd3,
           sccb_stop    = 3'd4;
localparam MSG_INDEX = 7'd77;
	
reg [1:0] xclk_div = 2'b00;
always @(posedge clk_100 or negedge rst_n) begin
    if (!rst_n) xclk_div <= 2'b00;
    else        xclk_div <= xclk_div + 1'b1;
end
assign cmos_xclk = xclk_div[1];

reg [6:0]  message_index_q = 7'd0, message_index_d;
reg [15:0] rom_data;
always @* begin
    case (message_index_q)
        7'd0:  rom_data = 16'h12_80; 7'd1:  rom_data = 16'h12_04; 7'd2:  rom_data = 16'h15_20;
        7'd3:  rom_data = 16'h40_d0; 7'd4:  rom_data = 16'h12_04; 7'd5:  rom_data = 16'h11_80;
        7'd6:  rom_data = 16'h0C_00; 7'd7:  rom_data = 16'h3E_00; 7'd8:  rom_data = 16'h04_00;
        7'd9:  rom_data = 16'h40_d0; 7'd10: rom_data = 16'h3a_04; 7'd11: rom_data = 16'h14_18;
        7'd12: rom_data = 16'h4F_B3; 7'd13: rom_data = 16'h50_B3; 7'd14: rom_data = 16'h51_00;
        7'd15: rom_data = 16'h52_3d; 7'd16: rom_data = 16'h53_A7; 7'd17: rom_data = 16'h54_E4;
        7'd18: rom_data = 16'h58_9E; 7'd19: rom_data = 16'h3D_C0; 7'd20: rom_data = 16'h17_14;
        7'd21: rom_data = 16'h18_02; 7'd22: rom_data = 16'h32_80; 7'd23: rom_data = 16'h19_03;
        7'd24: rom_data = 16'h1A_7B; 7'd25: rom_data = 16'h03_0A; 7'd26: rom_data = 16'h0F_41;
        7'd27: rom_data = 16'h1E_00; 7'd28: rom_data = 16'h33_0B; 7'd29: rom_data = 16'h3C_78;
        7'd30: rom_data = 16'h69_00; 7'd31: rom_data = 16'h74_00; 7'd32: rom_data = 16'hB0_84;
        7'd33: rom_data = 16'hB1_0c; 7'd34: rom_data = 16'hB2_0e; 7'd35: rom_data = 16'hB3_80;
        7'd36: rom_data = 16'h70_3a; 7'd37: rom_data = 16'h71_35; 7'd38: rom_data = 16'h72_11;
        7'd39: rom_data = 16'h73_f0; 7'd40: rom_data = 16'ha2_02; 7'd41: rom_data = 16'h7a_20;
        7'd42: rom_data = 16'h7b_10; 7'd43: rom_data = 16'h7c_1e; 7'd44: rom_data = 16'h7d_35;
        7'd45: rom_data = 16'h7e_5a; 7'd46: rom_data = 16'h7f_69; 7'd47: rom_data = 16'h80_76;
        7'd48: rom_data = 16'h81_80; 7'd49: rom_data = 16'h82_88; 7'd50: rom_data = 16'h83_8f;
        7'd51: rom_data = 16'h84_96; 7'd52: rom_data = 16'h85_a3; 7'd53: rom_data = 16'h86_af;
        7'd54: rom_data = 16'h87_c4; 7'd55: rom_data = 16'h88_d7; 7'd56: rom_data = 16'h89_e8;
        7'd57: rom_data = 16'h13_e0; 7'd58: rom_data = 16'h00_00; 7'd59: rom_data = 16'h10_00;
        7'd60: rom_data = 16'h0d_40; 7'd61: rom_data = 16'h14_18; 7'd62: rom_data = 16'ha5_05;
        7'd63: rom_data = 16'hab_07; 7'd64: rom_data = 16'h24_95; 7'd65: rom_data = 16'h25_33;
        7'd66: rom_data = 16'h26_e3; 7'd67: rom_data = 16'h9f_78; 7'd68: rom_data = 16'ha0_68;
        7'd69: rom_data = 16'ha1_03; 7'd70: rom_data = 16'ha6_d8; 7'd71: rom_data = 16'ha7_d8;
        7'd72: rom_data = 16'ha8_f0; 7'd73: rom_data = 16'ha9_90; 7'd74: rom_data = 16'haa_94;
        7'd75: rom_data = 16'h13_e5; 7'd76: rom_data = 16'h1E_03; 7'd77: rom_data = 16'h69_06;
        default: rom_data = 16'h00_00;
    endcase
end

reg [3:0]  state_q = 4'd0, state_d;
reg [2:0]  sccb_state_q = 3'd0, sccb_state_d;
reg [7:0]  addr_q, addr_d;
reg [7:0]  data_q, data_d;
reg [7:0]  brightness_q, brightness_d;
reg [7:0]  contrast_q, contrast_d;
reg        start, stop;
reg [7:0]  wr_data;
wire       rd_tick;
wire [1:0] ack;
wire [7:0] rd_data;
wire [3:0] i2c_state;
reg [3:0]  led_q = 4'd0, led_d;
reg [27:0] delay_q = 28'd0, delay_d;
reg        start_delay_q = 1'b0, start_delay_d;
reg        delay_finish;
reg [15:0] pixel_q, pixel_d;
reg        wr_en;
wire       full;
wire       key0_tick, key1_tick, key2_tick, key3_tick;
reg [19:0] sccb_timeout_q = 20'd0, sccb_timeout_d;
reg        sccb_timeout_hit;

reg pclk_1, pclk_2, href_1, href_2, vsync_1, vsync_2;

reg [1:0] sw_flip_d1 = 2'b00, sw_flip_d2 = 2'b00;
reg flip_req = 1'b0;
always @(posedge clk_100 or negedge rst_n) begin
    if (!rst_n) begin
        state_q         <= 4'd0;
        led_q           <= 4'd0;
        delay_q         <= 28'd0;
        start_delay_q   <= 1'b0;
        message_index_q <= 7'd0;
        pixel_q         <= 16'd0;
        sccb_state_q    <= 3'd0;
        addr_q          <= 8'd0;
        data_q          <= 8'd0;
        brightness_q    <= 8'd0;
        contrast_q      <= 8'd0;
        sccb_timeout_q  <= 20'd0;
        pclk_1  <= 1'b0; pclk_2  <= 1'b0;
        href_1  <= 1'b0; href_2  <= 1'b0;
        vsync_1 <= 1'b0; vsync_2 <= 1'b0;
		  sw_flip_d1 <= 2'b00;
        sw_flip_d2 <= 2'b00;
        flip_req   <= 1'b0;
    end else begin
        state_q         <= state_d;
        led_q           <= led_d;
        delay_q         <= delay_d;
        start_delay_q   <= start_delay_d;
        message_index_q <= message_index_d;
        pixel_q         <= pixel_d;
        sccb_state_q    <= sccb_state_d;
        addr_q          <= addr_d;
        data_q          <= data_d;
        brightness_q    <= brightness_d;
        contrast_q      <= contrast_d;
        sccb_timeout_q  <= sccb_timeout_d;
        pclk_1  <= cmos_pclk;  pclk_2  <= pclk_1;
        href_1  <= cmos_href;  href_2  <= href_1;
        vsync_1 <= cmos_vsync; vsync_2 <= vsync_1;
sw_flip_d1 <= sw_flip;
        sw_flip_d2 <= sw_flip_d1;
        
        if (sw_flip_d1 != sw_flip_d2) 
            flip_req <= 1'b1; // Cờ yêu cầu cập nhật lật hình
        else if (sccb_state_q == sccb_idle && i2c_state == 4'd0 && flip_req) 
            flip_req <= 1'b0; // Xóa cờ khi FSM đã nhận lệnh
    end
end

always @* begin
    state_d          = state_q;
    led_d            = led_q;
    start            = 1'b0;
    stop             = 1'b0;
    wr_data          = 8'd0;
    start_delay_d    = start_delay_q;
    delay_d          = delay_q;
    delay_finish     = 1'b0;
    message_index_d  = message_index_q;
    pixel_d          = pixel_q;
    wr_en            = 1'b0;
    sccb_state_d     = sccb_state_q;
    addr_d           = addr_q;
    data_d           = data_q;
    brightness_d     = brightness_q;
    contrast_d       = contrast_q;
    sccb_timeout_d   = sccb_timeout_q;
    sccb_timeout_hit = 1'b0;

    if (sccb_state_q == sccb_address || sccb_state_q == sccb_data || sccb_state_q == sccb_stop) begin
        sccb_timeout_d = sccb_timeout_q + 1'b1;
        if (sccb_timeout_q == 20'hFFFFF) begin
            sccb_timeout_hit = 1'b1;
            sccb_timeout_d   = 20'd0;
        end
    end else begin
        sccb_timeout_d = 20'd0;
    end

    if (start_delay_q) delay_d = delay_q + 1'b1;

    if (delay_q[16] && message_index_q != (MSG_INDEX + 1'b1) && state_q != start_sccb && state_q != idle) begin
        delay_finish  = 1'b1;
        start_delay_d = 1'b0;
        delay_d       = 28'd0;
    end
    else if (delay_q[26] && message_index_q == (MSG_INDEX + 1'b1)) begin
        delay_finish  = 1'b1;
        start_delay_d = 1'b0;
        delay_d       = 28'd0;
    end

    case (state_q)
        idle: begin
            if (delay_q[26]) begin
                state_d       = start_sccb;
                start_delay_d = 1'b0;
                delay_d       = 28'd0;
            end else start_delay_d = 1'b1;
        end

        start_sccb: begin
            start   = 1'b1;
            wr_data = 8'h42;
            state_d = write_address;
        end

        write_address: begin
            if (ack[1]) begin
                wr_data = rom_data[15:8];
                state_d = write_data;
            end else if (sccb_timeout_hit) begin
                stop    = 1'b1;
                state_d = start_sccb;
            end
        end

        write_data: begin
            if (ack[1]) begin
                wr_data = rom_data[7:0];
                state_d = digest_loop;
            end else if (sccb_timeout_hit) begin
                stop    = 1'b1;
                state_d = start_sccb;
            end
        end

        digest_loop: begin
            if (ack[1]) begin
                stop            = 1'b1;
                start_delay_d   = 1'b1;
                message_index_d = message_index_q + 1'b1;
                state_d         = delay;
            end else if (sccb_timeout_hit) begin
                stop    = 1'b1;
                state_d = start_sccb;
            end
        end

        delay: begin
            if (message_index_q == (MSG_INDEX + 1'b1) && delay_finish) begin
                state_d = wait_vsync_high; // Thoát ra an toàn, không phụ thuộc vào vsync
            end else if (i2c_state == 4'd0 && delay_finish)
                state_d = start_sccb;
        end

        wait_vsync_high: begin
            if (vsync_1 && vsync_2)        // Đợi VSYNC lên mức CAO (đầu frame)
                state_d = wait_vsync_low;
        end
        
        wait_vsync_low: begin
            if (!vsync_1 && !vsync_2)      // Đợi VSYNC xuống THẤP (bắt đầu quét ảnh)
                state_d = byte1;
        end

        byte1: begin
            if (pclk_1 && !pclk_2 && href_1 && href_2) begin
                pixel_d[15:8] = cmos_db;
                state_d       = byte2;
            end
            else if (vsync_1 && vsync_2)  
                state_d = wait_vsync_high; // Bị mất đồng bộ -> Về chờ
        end

        byte2: begin
            if (pclk_1 && !pclk_2 && href_1 && href_2) begin
                pixel_d[7:0] = cmos_db;
                state_d      = fifo_write;
            end
            else if (vsync_1 && vsync_2)  
                state_d = wait_vsync_high;
        end

        fifo_write: begin
            wr_en   = 1'b1;
            state_d = byte1;
        end

        default: state_d = idle;
    endcase

    case (sccb_state_q)
        wait_init: begin
            if (state_q == byte1) begin
                sccb_state_d = sccb_idle;
                addr_d       = 8'd0; data_d = 8'd0;
                brightness_d = 8'h00; contrast_d = 8'h40;
            end
        end
sccb_idle: begin
            if (i2c_state == 4'd0) begin
                
                // [THÊM MỚI] Gửi lệnh lật hình khi gạt Switch
                if (flip_req) begin
                    start = 1'b1; 
                    wr_data = 8'h42; 
                    addr_d = 8'h1E; 
                    // SW[3] (Bit 1) = Lật ngang (0x20) | SW[2] (Bit 0) = Lật dọc (0x10) | Gốc (0x03)
                    data_d = 8'h03 | (sw_flip_d2[1] ? 8'h20 : 8'h00) | (sw_flip_d2[0] ? 8'h10 : 8'h00);
                    sccb_state_d = sccb_address;
                end
                
                // KEY0: Tăng độ sáng (Cộng thêm 16, chốt trần ở mức sáng tối đa 0x7F)
                if (key0_tick) begin
                    if (brightness_q[7] == 1'b1) begin // Đang ở dải âm (tối)
                        if (brightness_q[6:0] > 7'h10) brightness_d = brightness_q - 8'h10;
                        else brightness_d = 8'h00;     // Chạm 0
                    end else begin                     // Đang ở dải dương (sáng)
                        if (brightness_q[6:0] < 7'h6F) brightness_d = brightness_q + 8'h10;
                        else brightness_d = 8'h7F;     // Chốt ở Max Sáng
                    end
                    start = 1'b1; wr_data = 8'h42; addr_d = 8'h55; data_d = brightness_d;
                    sccb_state_d = sccb_address;
                end
                
                // KEY1: Giảm độ sáng (Trừ đi 16, chốt đáy ở mức tối đa âm 0xFF)
                else if (key1_tick) begin
                    if (brightness_q[7] == 1'b0) begin // Đang ở dải dương (sáng)
                        if (brightness_q[6:0] > 7'h10) brightness_d = brightness_q - 8'h10;
                        else brightness_d = 8'h80;     // Chạm mốc Âm
                    end else begin                     // Đang ở dải âm (tối)
                        if (brightness_q[6:0] < 7'h6F) brightness_d = brightness_q + 8'h10;
                        else brightness_d = 8'hFF;     // Chốt ở Max Tối
                    end
                    start = 1'b1; wr_data = 8'h42; addr_d = 8'h55; data_d = brightness_d;
                    sccb_state_d = sccb_address;
                end
                
                // KEY2: Tăng độ tương phản (Thanh ghi Unsigned thông thường, chốt trần ở 0xFF)
                else if (key2_tick) begin
                    if (contrast_q < 8'hEF) contrast_d = contrast_q + 8'h10; 
                    else contrast_d = 8'hFF;
                    start = 1'b1; wr_data = 8'h42; addr_d = 8'h56; data_d = contrast_d; 
                    sccb_state_d = sccb_address;
                end
                
                // KEY3: Giảm độ tương phản (Chốt đáy ở 0x00)
                else if (key3_tick) begin
                    if (contrast_q > 8'h10) contrast_d = contrast_q - 8'h10; 
                    else contrast_d = 8'h00;
                    start = 1'b1; wr_data = 8'h42; addr_d = 8'h56; data_d = contrast_d; 
                    sccb_state_d = sccb_address;
                end
            end
        end
        sccb_address: begin
            if (sccb_timeout_hit) sccb_state_d = sccb_idle;
            else if (ack[1]) begin wr_data = addr_q; sccb_state_d = sccb_data; end
        end
        sccb_data: begin
            if (sccb_timeout_hit) sccb_state_d = sccb_idle;
            else if (ack[1]) begin wr_data = data_q; sccb_state_d = sccb_stop; end
        end
        sccb_stop: begin
            if (sccb_timeout_hit) sccb_state_d = sccb_idle;
            else if (ack[1]) begin stop = 1'b1; sccb_state_d = sccb_idle; end
        end
        default: sccb_state_d = wait_init;
    endcase
end

assign cmos_pwdn  = 1'b0;
assign cmos_rst_n = 1'b1;

reg [23:0] blink_ctr = 24'd0;
always @(posedge clk_100 or negedge rst_n) begin
    if (!rst_n) blink_ctr <= 24'd0;
    else        blink_ctr <= blink_ctr + 1'b1;
end
wire blink_fast = blink_ctr[22];
wire blink_slow = blink_ctr[23]; 

reg i2c_timeout_sticky = 1'b0;
always @(posedge clk_100 or negedge rst_n) begin
    if (!rst_n)              i2c_timeout_sticky <= 1'b0;
    else if (sccb_timeout_hit) i2c_timeout_sticky <= 1'b1;
    else if (key0_tick | key1_tick | key2_tick | key3_tick) i2c_timeout_sticky <= 1'b0;
end

reg fifo_full_sticky = 1'b0;
always @(posedge clk_100 or negedge rst_n) begin
    if (!rst_n) fifo_full_sticky <= 1'b0;
    else if (full) fifo_full_sticky <= 1'b1;
end

reg [3:0] led_debug;
always @* begin
    casex ({i2c_timeout_sticky, state_q})
        5'b1_xxxx: led_debug = {blink_fast, 1'b0, blink_fast, 1'b0};
        5'b0_0000: led_debug = 4'b0001;
        5'b0_0001: led_debug = 4'b0010;
        5'b0_0010: led_debug = 4'b0011;
        5'b0_0011: led_debug = {2'b00, blink_fast, 1'b1};
        5'b0_0100: led_debug = {2'b00, blink_slow, 1'b1};
        5'b0_0101: led_debug = 4'b0101; 
        5'b0_0110: led_debug = {blink_slow, 1'b1, blink_slow, 1'b0}; // wait_vsync_high
        5'b0_0111: led_debug = 4'b0111; 
        5'b0_1000: led_debug = 4'b0111; 
        5'b0_1001: led_debug = fifo_full_sticky ? 4'b1001 : 4'b1000;
        5'b0_1010: led_debug = {blink_fast, 1'b1, blink_fast, 1'b0}; // wait_vsync_low
        default:   led_debug = 4'b1111;
    endcase
end

assign led = led_debug;

i2c_top #(.freq(100_000)) m0 (
    .clk     (clk_100), .rst_n   (rst_n), .start   (start), .stop    (stop),
    .wr_data (wr_data), .rd_tick (rd_tick), .ack     (ack), .rd_data (rd_data),
    .scl     (cmos_scl), .sda     (cmos_sda), .state   (i2c_state)
);
fifo m2 (
    .aclr    (~rst_n), .data    (pixel_q), .rdclk   (clk_100), .rdreq   (rd_en),
    .wrclk   (clk_100), .wrreq   (wr_en), .q       (dout), .rdempty (),
    .rdusedw (data_count_r), .wrfull  (full), .wrusedw ()
);
debounce_explicit m3 (.clk(clk_100),.rst_n(rst_n),.sw(!key[0]),.db_level(),.db_tick(key0_tick));
debounce_explicit m4 (.clk(clk_100),.rst_n(rst_n),.sw(!key[1]),.db_level(),.db_tick(key1_tick));
debounce_explicit m5 (.clk(clk_100),.rst_n(rst_n),.sw(!key[2]),.db_level(),.db_tick(key2_tick));
debounce_explicit m6 (.clk(clk_100),.rst_n(rst_n),.sw(!key[3]),.db_level(),.db_tick(key3_tick));
endmodule