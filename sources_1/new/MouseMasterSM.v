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


module MouseMasterSM(
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
    output [7:0] MOUSE_STATUS,
    output SEND_INTERRUPT
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
    //Any error during this sequence, restart initiallisation
    //
    //////////////////////////////////////////////////////////////////////////////////


    // State control
    reg [3:0] curr_state;
    reg [3:0] next_state;
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
    reg [7:0] curr_sendInterrupt;
    reg [7:0] next_sendInterrupt;


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
            curr_sendInterrupt <= 1'b0;
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
            curr_sendInterrupt <= next_sendInterrupt;
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

        case(curr_state)
        // Setup sequence
            4'b0000 : begin // wait for 10ms before initialisation
                if (curr_ctr == 1000000) begin
                    next_state = 4'b0001;
                    next_ctr = 0;
                end
                else begin
                    next_ctr = curr_ctr + 1;
                    next_ctr = curr_state;
                end
            end
            4'b0001 : begin // SU1
                next_state = 4'b0010;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hFF;
            end
            4'b0010 : begin // wait for confirmation of byte being sent
                if (BYTE_SENT) begin
                    next_state = 4'b0011;
                end
                else begin
                    next_state = curr_state;
                end
            end
            4'b0011 : begin // SU2
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 4'b0100;
                    end
                    else begin
                        next_state = 4'b0000;
                    end
                    next_readEnable = 1'b1;
                end
                else begin
                    next_state = curr_state;
                    next_readEnable = 1'b0;
                end
            end
            4'b0100 : begin // SU3
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hAA) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 4'b0101;
                    end
                    else begin
                        next_state = 4'b0000;
                    end
                    next_readEnable = 1'b1;
                end
                else begin
                    next_state = curr_state;
                    next_readEnable = 1'b0;
                end
            end
            4'b0101 : begin // SU4
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'h00) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 4'b0110;
                    end
                    else begin
                        next_state = 4'b0000;
                    end
                    next_readEnable = 1'b1;
                end
                else begin
                    next_state = curr_state;
                    next_readEnable = 1'b0;
                end
            end
            4'b0110 : begin // SU5
                next_state = 4'b0111;
                next_sendByte = 1'b1;
                next_byteToSend = 8'hF4;
            end
            4'b0111 : begin // wait for confirmation of byte being sent
                if (BYTE_SENT) begin
                    next_state = 4'b1000;
                end
                else begin
                    next_state = curr_state;
                end
            end
            4'b1000 : begin // SU6
                if (BYTE_READY) begin
                    if ((BYTE_READ == 8'hF4) & (BYTE_ERROR_CODE == 2'b00)) begin
                        next_state = 4'b1001;
                    end
                    else begin
                        next_state = 4'b0000;
                    end
                    next_readEnable = 1'b1;
                end
                else begin
                    next_state = curr_state;
                    next_readEnable = 1'b0;
                end
            end
        
        // Reading
            4'b1001 : begin
                if (BYTE_READY & (BYTE_ERROR_CODE == 2'b00)) begin
                    next_state = 4'b1010;
                    next_status = BYTE_READ;

                    next_ctr = curr_ctr;
                    next_readEnable = curr_readEnable;
                end
                else begin
                    next_state = 4'b0000;
                    next_ctr = 0;
                    next_readEnable = 1'b1;

                    next_status = curr_status;
                end
            end
            4'b1010 : begin
                if (BYTE_READY & (BYTE_ERROR_CODE == 2'b00)) begin
                    next_state = 4'b1010;
                    next_status = BYTE_READ;

                    next_ctr = curr_ctr;
                    next_readEnable = curr_readEnable;
                end
                else begin
                    next_state = 4'b0000;
                    next_ctr = 0;
                    next_readEnable = 1'b1;

                    next_status = curr_status;
                end
            end
            4'b1011 : begin
                if (BYTE_READY & (BYTE_ERROR_CODE == 2'b00)) begin
                    next_state = 4'b1010;
                    next_status = BYTE_READ;

                    next_ctr = curr_ctr;
                    next_readEnable = curr_readEnable;
                end
                else begin
                    next_state = 4'b0000;
                    next_ctr = 0;
                    next_readEnable = 1'b1;

                    next_status = curr_status;
                end
            end
            4'b1100 : begin
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
    assign MOUSE_STATUS = curr_status;
    assign SEND_INTERRUPT = curr_sendInterrupt;

endmodule
