`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: The University of Edinburgh
// Engineer: Dawei Sun
// 
// Create Date:    24.02.2022 20:45:09
// Design Name: 
// Module Name:    MouseMasterSM 
// Project Name: 
// Target Devices: 
// Tool versions: 
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
    // Internal Signals
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
	
    // State Control
    reg [5:0] curr_state, next_state;
    reg [23:0] curr_ctr, next_ctr;

    // Transmitter Control
    reg curr_sendByte, next_sendByte;
    reg [7:0] curr_byteToSend, next_byteToSend;

    //Receiver Control
    reg curr_readEnable, next_readEnable;

    //Data Registers
    reg [7:0] curr_status, next_status;
    reg [7:0] curr_DX, next_DX;
    reg [7:0] curr_DY, next_DY;
    reg [7:0] curr_DZ, next_DZ;
    reg curr_sendInterrupt, next_sendInterrupt;
    reg curr_intelliMode, next_intelliMode;


    // Sequential
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            curr_state <= 4'h0;
            curr_ctr <= 0;
            curr_sendByte <= 1'b0;
            curr_byteToSend <= 8'h00;
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
        next_DZ = curr_DZ;
        next_sendInterrupt = 1'b0;
        next_intelliMode = curr_intelliMode;
        
        case (curr_state)
        // Initialise State - Wait here for 10ms before trying to initialise the mouse.
            0 : begin
                if (curr_ctr == 5000000) begin
                    next_state = 1;
                    next_ctr = 0;
                end 
                else begin
                    next_ctr = curr_ctr + 1;
                end
                next_intelliMode = 1'b0;
            end

        // Start initialisation by sending FF
            1 : begin
                next_state = 2;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hFF;
            end
            // Wait for confirmation of the byte being sent
            2 : begin
                if (BYTE_SENT) begin
                    next_state = 3;
                end
            end
            // Wait for confirmation of a byte being received
            // If the byte is FA goto next state, else re-initialise.
            3 : begin // SU2
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 4;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Wait for self-test pass confirmation
            // If the byte received is AA goto next state, else re-initialise
            4 : begin // SU3
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hAA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 5;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Wait for confirmation of a byte being received
            // If the byte is 00 goto next state (MOUSE ID) else re-initialise
            5 : begin // SU4
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'h00) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 6;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Send F4 - to start mouse transmit
            6 : begin // SU5
                next_state = 7;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF4;
            end
            7 : begin
                if (BYTE_SENT) begin
                    next_state = 8;
                end
            end
            8 : begin // SU6
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 9;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Enable intellimouse mode by sending set sample rate command with 200, 100 and 80
        // Set sample rate
            9 : begin
                next_state = 10;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF3;
            end
            10 : begin
                if (BYTE_SENT) begin
                    next_state = 11;
                end
            end
            11 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 12;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Sample rate value 200
            12 : begin
                next_state = 13;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hC8;
            end
            13 : begin
                if (BYTE_SENT) begin
                    next_state = 14;
                end
            end
            14 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 15;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Set sample rate
            15 : begin
                next_state = 16;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF3;
            end
            16 : begin
                if (BYTE_SENT) begin
                    next_state = 17;
                end
            end
            17 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 18;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Sample rate vaue 100
            18 : begin
                next_state = 19;
                next_sendByte = 1'b1;
                next_byteToSend = 8'h64;
            end
            19 : begin
                if (BYTE_SENT) begin
                    next_state = 20;
                end
            end
            20 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 21;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Set sample rate
            21 : begin
                next_state = 22;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF3;
            end
            22 : begin
                if (BYTE_SENT) begin
                    next_state = 23;
                end
            end
            23 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 24;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Sample rate value 80
            24 : begin
                next_state = 25;
                next_sendByte = 1'b1;
                next_byteToSend = 8'h50;
            end
            25 : begin
                if (BYTE_SENT) begin
                    next_state = 26;
                end
            end
            26 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 27;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Request ID
            27 : begin
                next_state = 28;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF2;
            end
            28 : begin
                if (BYTE_SENT) begin
                    next_state = 29;
                end
            end
            29 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 30;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end

        // Read ID
            30 : begin
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'h03) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 31;
                        next_intelliMode = 1'b1;
                    end	
                    else if ((BYTE_READ == 8'h00) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 31;
                        next_intelliMode = 1'b0;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end


        // Reading
            31 : begin
                if (BYTE_READY) begin
                    if (BYTE_ERROR_CODE == 2'b00) begin
                        next_state = 32;
                        next_status = BYTE_READ;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end
            32 : begin
                if (BYTE_READY) begin
                    if (BYTE_ERROR_CODE == 2'b00) begin
                        next_state = 33;
                        next_DX = BYTE_READ;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end
            33 : begin
                if (BYTE_READY) begin
                    if (BYTE_ERROR_CODE == 2'b00) begin
                        if (curr_intelliMode) begin // whether to wait for the fourth byte
                            next_state = 34;
                        end
                        else begin
                            next_state = 35;
                        end
                        next_DY = BYTE_READ;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end
            34 : begin // fourth byte
                if (BYTE_READY) begin
                    if (BYTE_ERROR_CODE == 2'b00) begin
                        next_state = 35;
                        next_DZ = BYTE_READ;
                    end
                    else begin
                        next_state = 0;
                    end
                end
                next_readEnable = 1'b1;
            end
            35 : begin
                next_state = 31;
                next_sendInterrupt = 1'b1;
            end
            default : begin
                next_state = 0;
                next_ctr = 0;
                next_sendByte = 1'b0;
                next_byteToSend = 8'hFF;
                next_readEnable = 1'b0;
                next_status = 8'h00;
                next_DX = 8'h00;
                next_DY = 8'h00;
                next_DZ = 8'h00;
                next_sendInterrupt = 1'b0;
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
