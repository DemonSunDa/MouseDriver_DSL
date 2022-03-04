`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Dawei Sun
// 
// Create Date: 24.02.2022 20:45:09
// Design Name: MouseDriver
// Module Name: MouseMasterSM
// Project Name: DSL
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module MouseMasterSM (
    // Standard Inputs
    input CLK,
    input RESET,
    // Transmitter Control
    output SEND_BYTE,
    output [7:0] BYTE_TO_SEND,
    input BYTE_SENT,
    // Receiver Control
    output READ_ENABLE,
    input [7:0] BYTE_READ,
    input [1:0] BYTE_ERROR_CODE,
    input BYTE_READY,
    // Data Registers
    output [7:0] MOUSE_DX,
    output [7:0] MOUSE_DY,
    output [7:0] MOUSE_DZ,
    output [7:0] MOUSE_STATUS,
    output SEND_INTERRUPT,
    // Internal signal
    output [3:0] MasterStateCode
);

    
    //////////////////////////////////////////////////////////////////////////////////
    //
    // Main state machine
    //
    // Setup sequence
    // SU1) Send FF -- Reset
    // SU2) Read FA -- Mouse acknowledge
    // SU3) Read AA -- Self-test pass
    // SU4) Read 00 -- Mouse ID
    // SU5) Send F4 -- Start transmitting 
    // SU6) Read FA -- Mouse acknowledge (F4 in this case, parity check skipped)
    // Any error during this sequence, goto SU1
    //
    // Setup sequence finished, flag read enable
    // Host read mouse information 3 bytes at a time
    // S1) Wait for first read. Save to Status upon arrival. Goto S2.
    // S2) Wait for second read. Save to DX upon arrival. Goto S3.
    // S3) Wait for third read. Save to DY upon arrival. Goto S1.
    // Send interrupt
    // Any error during this sequence, restart initiallisation
    //
    //////////////////////////////////////////////////////////////////////////////////


    // State control
    reg [5:0] curr_state;
    reg [5:0] next_state;
    reg [23:0] curr_ctr;
    reg [23:0] next_ctr;

    // Transmitter control
    reg curr_sendByte;
    reg next_sendByte;
    reg [7:0] curr_byteToSend;
    reg [7:0] next_byteToSend;

    // Receiver control
    reg curr_readEnable;
    reg next_readEnable;

    // Data registers
    reg [7:0] curr_status;
    reg [7:0] next_status;
    reg [7:0] curr_DX;
    reg [7:0] next_DX;
    reg [7:0] curr_DY;
    reg [7:0] next_DY;
    reg [7:0] curr_DZ;
    reg [7:0] next_DZ;
    reg curr_sendInterrupt;
    reg next_sendInterrupt;
    reg curr_intelliMode;
    reg next_intelliMode;


    // Sequential
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            curr_state <= 4'h0;
            curr_ctr <= 0;
            curr_sendByte <= 1'b0;
            curr_byteToSend <= 8'hFF;
            curr_readEnable <= 1'b0;
            curr_status <= 8'h00;
            curr_DX <= 8'h00;
            curr_DY <= 8'h00;
            curr_DZ <= 8'h00;
            curr_sendInterrupt <= 1'b0;
            curr_intelliMode <= 1'b0;
        end
        else begin
            curr_state <= next_state;
            curr_ctr <= next_ctr;
            curr_sendByte <= next_sendByte;
            curr_byteToSend <= next_byteToSend;
            curr_readEnable <= next_readEnable;
            curr_status <= next_status;
            curr_DX <= next_DX;
            curr_DY <= next_DY;
            curr_DZ <= next_DZ;
            curr_sendInterrupt <= next_sendInterrupt;
            curr_intelliMode <= next_intelliMode;
        end
    end


    // Combinational
    always @(*) begin
        next_state = curr_state;
        next_ctr = curr_ctr;
        next_sendByte = 1'b0;
        next_byteToSend = curr_byteToSend;
        next_readEnable = 1'b0;
        next_status = curr_status;
        next_DX = curr_DX;
        next_DY = curr_DY;
        next_sendInterrupt = 1'b0;
        next_intelliMode = curr_intelliMode;

        case (curr_state)
        // Setup sequence
            6'b000000 : begin // wait for 10ms before initialisation
                if (curr_ctr == 5000000) begin
                    next_state = 6'b000001;
                    next_ctr = 0;
                end
                else begin
                    next_ctr = curr_ctr + 1;
                end
                next_intelliMode = 1'b0;
            end
        // state 1 to 3 form a typical send byte sequence
            6'b000001 : begin // SU1
                next_state = 6'b000010;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hFF;
            end
            6'b000010 : begin // wait for confirmation of byte being sent
                if (BYTE_SENT) begin
                    next_state = 6'b000011;
                end
            end
            6'b000011 : begin // SU2
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b000100;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end

            6'b000100 : begin // SU3
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hAA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b000101;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end
            6'b000101 : begin // SU4
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'h00) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b000110;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end

            6'b000110 : begin // SU5
                next_state = 6'b000111;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF4;
            end
            6'b000111 : begin // wait for confirmation of byte being sent
                if (BYTE_SENT) begin
                    next_state = 6'b001000;
                end
            end
            6'b001000 : begin // SU6
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b001001;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end
        
        // Enable scroll
            6'b001001 : begin
                next_state = 6'b001010;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF3;
            end
            6'b001010 : begin
                if (BYTE_SENT) begin
                    next_state = 6'b001011;
                end
            end
            6'b001011 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b001100;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end

            6'b001100 : begin // Send sample rate change to 200
                next_state = 6'b001101;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hC8;
            end
            6'b001101 : begin
                if (BYTE_SENT) begin
                    next_state = 6'b001110;
                end
            end
            6'b001110 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b001111;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end

            6'b001111 : begin // send sample rate change request
                next_state = 6'b010000;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF3;
            end
            6'b010000 : begin
                if (BYTE_SENT) begin
                    next_state = 6'b010001;
                end
            end
            6'b010001 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b010010;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end

            6'b010010 : begin // send sample rate value 100
                next_state = 6'b010011;
                next_sendByte = 1'b1;
                next_byteToSend = 8'h64;
            end
            6'b010011 : begin
                if (BYTE_SENT) begin
                    next_state = 6'b010100;
                end
            end
            6'b010100 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b010101;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end

            6'b010101 : begin // send sample rate change request
                next_state = 6'b010110;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF3;
            end
            6'b010110 : begin
                if (BYTE_SENT) begin
                    next_state = 6'b010111;
                end
            end
            6'b010111 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b011000;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end

            6'b011000 : begin // send sample rate value 80
                next_state = 6'b011001;
                next_sendByte = 1'b1;
                next_byteToSend = 8'h50;
            end
            6'b011001 : begin
                if (BYTE_SENT) begin
                    next_state = 6'b011010;
                end
            end
            6'b011010 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b011011;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end

            6'b011011 : begin // send ID request
                next_state = 6'b011100;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF2;
            end
            6'b011100 : begin
                if (BYTE_SENT) begin
                    next_state = 6'b011101;
                end
            end
            6'b011101 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b011110;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end

            6'b011110 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'h03) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b011111;
                        next_intelliMode = 1'b1;
                    end
                    else if ((BYTE_READ == 8'h00) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6'b011111;
                        next_intelliMode = 1'b0;
                    end
                    else begin
                        next_state = 6'b000000;
                    end
                end
                next_readEnable = 1'b1;
            end
            

        // Reading
            6'b011111 : begin
                if (BYTE_READY & (BYTE_ERROR_CODE == 2'b00)) begin
                    next_state = 6'b100000;
                    next_status = BYTE_READ;
                end
                else begin
                    next_state = 6'b000000;
                end
                next_readEnable = 1'b1;
            end
            6'b100000 : begin
                if (BYTE_READY & (BYTE_ERROR_CODE == 2'b00)) begin
                    next_state = 6'b100001;
                    next_DX = BYTE_READ;
                end
                else begin
                    next_state = 6'b000000;
                end
                next_readEnable = 1'b1;
            end
            6'b100001 : begin
                if (BYTE_READY & (BYTE_ERROR_CODE == 2'b00)) begin
                    if (curr_intelliMode) begin // whether to wait for the fourth byte
                        next_state = 6'b100010;
                    end
                    else begin
                        next_state = 6'b100011;
                    end
                    next_DY = BYTE_READ;
                end
                else begin
                    next_state = 4'b0000;
                end
                next_readEnable = 1'b1;
            end
            6'b100010 : begin // fourth byte
                if (BYTE_READY & (BYTE_ERROR_CODE == 2'b00)) begin
                    next_state = 6'b100011;
                    next_DZ = BYTE_READ;
                end
                else begin
                    next_state = 6'b000000;
                end
                next_readEnable = 1'b1;
            end
            6'b100011 : begin
                next_state = 4'b1001;
                next_sendInterrupt = 1'b1;
            end
            default : begin
                next_state = 4'b0000;
                next_ctr = 0;
                next_sendByte = 1'b0;
                next_byteToSend = 8'hFF;
                next_readEnable = 1'b0;
                next_status = 8'h00;
                next_DX = 8'h00;
                next_DY = 8'h00;
                next_sendInterrupt = 1'b0;
                next_intelliMode = 1'b0;
            end
        endcase
    end


    // Transmitter
    assign SEND_BYTE = curr_sendByte;
    assign BYTE_TO_SEND = curr_byteToSend;

    // Receiver
    assign READ_ENABLE = curr_readEnable;

    // Output mouse data
    assign MOUSE_DX = curr_DX;
    assign MOUSE_DY = curr_DY;
    assign MOUSE_DZ = curr_DZ;
    assign MOUSE_STATUS = curr_status;
    assign SEND_INTERRUPT = curr_sendInterrupt;
    assign MasterStateCode = curr_state;

endmodule
