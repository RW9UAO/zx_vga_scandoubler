`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//	color capture rising edge of 14MHz
// ZX_VSYNC change on falling, check on rising edge of 14MHz
// ZX_HSYNC change on falling, check on rising edge of 14MHz
//
//////////////////////////////////////////////////////////////////////////////////
module main(
	//input wire input50MHZ,
	//----------------------------
	output wire [18:0]SRAM_Addr,
	inout wire [7:0]SRAM_D,
	output wire SRAM_OE,
	output wire SRAM_WE,
	output wire SRAM_CS,
	//----------------------------
	output wire VGA_VSYNC,
	output wire VGA_HSYNC,
	output wire [1:0] VGA_R,
	output wire [1:0] VGA_G,
	output wire [1:0] VGA_B,
	//-------------------------
	input wire ZX_R,
	input wire ZX_G,
	input wire ZX_B,
	input wire ZX_I,
	input wire ZX_VSYNC,
	input wire ZX_HSYNC,
	input wire ZX_14M
	//-------------------------
    );
//==================================================================================
// memory
reg [7:0]WR_REG;
reg [7:0]RD_REG;

// vga
reg [9:0]VGA_H;
reg [9:0]VGA_V;
reg r,rb;
reg g,gb;
reg b,bb;
wire blank;

reg [8:0]temp_c;
reg [9:0]temp2_c;
// zx
reg [9:0]VIDEO_H;
reg [8:0]VIDEO_V;

wire pix_clk;
reg SSI, SSI2;
reg KSI;

//==================================================================================
// VGA signals
assign VGA_R = {r,rb};
assign VGA_G = {g,gb};
assign VGA_B = {b,bb};
assign VGA_HSYNC = ( VGA_H > 8 && VGA_H < 62 ) ? 1'b0 : 1'b1;
assign VGA_VSYNC = ( VGA_V[9:0] == 74 || VGA_V[9:0] == 75 ) ? 1'b0 : 1'b1; 
assign blank = ( VGA_H < 89 || VGA_H > 400 || VGA_V[9:0] < 109 )? 1'b1 : 1'b0;

assign SRAM_WE = ( ~( VIDEO_H[1] && VIDEO_H[0] ));
assign SRAM_OE = ( VIDEO_H[0] );
assign SRAM_CS = 1'b0;
assign SRAM_D = ( VIDEO_H[0] == 1'b1 ) ? WR_REG : 8'bzzzzZZZZ;
assign SRAM_Addr = ( VIDEO_H[0] == 1'b1 ) ? { 1'b0,VIDEO_V[8:0], temp2_c[9:2] } : { 1'b0,VGA_V[9:1], temp_c[8:1] };

assign pix_clk = ZX_14M;
//==================================================================================
// main counters
always @(negedge pix_clk) begin
	
	SSI <= ZX_HSYNC;	// sync delay for guaranted capture
	SSI2 <= SSI;
	
	if( {SSI2, SSI, ZX_HSYNC} == 3'b100 ) begin	// sync falling edge
			VGA_H <= 0;
			temp_c <= 0;
			VIDEO_H <= 0;
			temp2_c <= 0;
	end else begin
		// 14.000.000 448 = / 31,25 kHz VGA Hsync	
		if ( VGA_H == 447 ) begin						// VGA string half of PAL string
			VGA_H <= 0;
			temp_c <= 0;
		end else begin
			VGA_H <= VGA_H + 1'b1;
			if( VGA_H > 80 ) begin						// offset, move picture right
				temp_c <= temp_c + 1'b1;
			end
		end
		
			VIDEO_H <= VIDEO_H + 1'b1;
			if( VIDEO_H > 64 ) begin
				temp2_c <= temp2_c + 1'b1;
			end

	end
end
//-------------------------------------------
// on string start
always @(negedge VGA_H[8] ) begin

		// 14.000.000 / 448 / (587-44) = 57,5 Hz VGA Vsync
		if ( VGA_V[9:0] == 587 ) begin
			VGA_V[9:0] <= 44;
		end else begin
			VGA_V <= VGA_V + 1'b1;
		end
end
//-------------------------------------------
// capture string counter
always @(negedge VIDEO_H[9] ) begin
		KSI <= ZX_VSYNC;	// sync delay
		
		if( {KSI, ZX_VSYNC} == 2'b10 ) begin
			VIDEO_V <= 0;
		end else begin
			VIDEO_V <= VIDEO_V + 1'b1;	
		end
end
//-------------------------------------------
// strobe RGB to temp register
always @(posedge pix_clk ) begin
	if( VIDEO_H[0] == 1 )begin
		if( VIDEO_H[1] == 0 )begin
			WR_REG[3] <= ZX_R;
			WR_REG[2] <= ZX_G;
			WR_REG[1] <= ZX_B;
			WR_REG[0] <= ZX_I;
		end else begin
			WR_REG[7] <= ZX_R;
			WR_REG[6] <= ZX_G;
			WR_REG[5] <= ZX_B;
			WR_REG[4] <= ZX_I;
		end
	end
end
//-------------------------------------------
// strobe data from SRAM
always @(posedge pix_clk) begin
	if( VGA_H[0] == 0 )begin
		RD_REG <= SRAM_D;
	end
end
//-------------------------------------------
// VGA picture magic
always @(negedge pix_clk) begin
	if( blank == 0 ) begin
		if( VGA_H[0] == 0)begin
			r <= RD_REG[3];
			g <= RD_REG[2];
			b <= RD_REG[1];
			rb <= RD_REG[0];
			gb <= RD_REG[0];
			bb <= RD_REG[0];
		end else begin		
			r <= RD_REG[7];
			g <= RD_REG[6];
			b <= RD_REG[5];
			rb <= RD_REG[4];
			gb <= RD_REG[4];
			bb <= RD_REG[4];
		end
	end else begin	// blank area
		r <= 0;
		g <= 0;
		b <= 0;
		rb <= 0;
		gb <= 0;
		bb <= 0;
	end
end

endmodule
