`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.02.2022 00:16:01
// Design Name: 
// Module Name: MouseTransmitter 
// Project Name: 
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


module MouseTransmitter (
    // Standard Inputs
    input CLK,
    input RESET,
    // Mouse IO
    input CLK_MOUSE_IN,
    output CLK_MOUSE_OUT_EN, // allows for the control of the clock line
    input DATA_MOUSE_IN,
    output DATA_MOUSE_OUT,
    output DATA_MOUSE_OUT_EN,
    // Control
    input SEND_BYTE,
    input [7:0] BYTE_TO_SEND,
    output BYTE_SENT
);


    reg CLK_MOUSE_SYNC;
    always @(posedge CLK) begin
        CLK_MOUSE_SYNC <= CLK_MOUSE_IN;
    end
        

    reg [3:0] curr_state, next_state;
    reg curr_MSClkOutWE, next_MSClkOutWE;
    reg curr_MSDataOut, next_MSDataOut;
    reg curr_MSDataOutWE, next_MSDataOutWE;
    reg [15:0] curr_sendCtr, next_sendCtr;
    reg curr_byteSent, next_byteSent;
    reg [7:0] curr_byteToSend, next_byteToSend;


    // Sequential
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            curr_state <= 0;
            curr_MSClkOutWE <= 1'b0;
            curr_MSDataOut <= 1'b0;
            curr_MSDataOutWE <= 1'b0;
            curr_sendCtr <= 0;
            curr_byteSent <= 1'b0;
            curr_byteToSend <= 0;
        end
        else begin
            curr_state <= next_state;
            curr_MSClkOutWE <= next_MSClkOutWE;
            curr_MSDataOut <= next_MSDataOut;
            curr_MSDataOutWE <= next_MSDataOutWE;
            curr_sendCtr <= next_sendCtr;
            curr_byteSent <= next_byteSent;
            curr_byteToSend <= next_byteToSend;
        end
    end


    // Combinational
    always @(*) begin
        next_state = curr_state;
        next_MSClkOutWE = 1'b0;
        next_MSDataOut = 1'b0;
        next_MSDataOutWE = curr_MSDataOutWE;
        next_sendCtr = curr_sendCtr;
        next_byteSent = 1'b0;
        next_byteToSend = curr_byteToSend;
        
        case (curr_state)
            0 : begin
                if (SEND_BYTE) begin
                    next_state = 1;
                    next_byteToSend = BYTE_TO_SEND;
                end
                next_MSDataOutWE = 1'b0;
            end
            1 : begin // bring CLK low for at least 100us
                if (curr_sendCtr == 6000) begin
                    next_state = 2;
                    next_sendCtr = 0;
                end
                else begin
                    next_sendCtr = curr_sendCtr + 1;
                end
                next_MSClkOutWE = 1'b1;
            end
            2 : begin // bring data line low and release CLK
                next_state = 3;
                next_MSDataOutWE = 1'b1;
            end
            3 : begin // start sending
                if (CLK_MOUSE_SYNC & ~CLK_MOUSE_IN) begin
                    next_state = 4;
                end
            end
            4 : begin // send byte
                if (CLK_MOUSE_SYNC & ~CLK_MOUSE_IN) begin
                    if (curr_sendCtr == 7) begin
                        next_state = 5;
                        next_sendCtr = 0;
                    end 
                    else begin
                        next_sendCtr = curr_sendCtr + 1;
                    end
                end
                next_MSDataOut = curr_byteToSend[curr_sendCtr];
            end
            5 : begin // send parity bit
                if (CLK_MOUSE_SYNC & ~CLK_MOUSE_IN) begin
                    next_state = 6;
                end
                next_MSDataOut = ~^curr_byteToSend[7:0];
            end
            6 : begin // end bit
                if (CLK_MOUSE_SYNC & ~CLK_MOUSE_IN) begin
                    next_state = 7;
                end
                next_MSDataOut = 1'b1;
            end
            7 : begin // release data line
                next_state = 8;
                next_MSDataOutWE = 1'b0;
            end
            8 : begin // wait device to set data line low
                if (~DATA_MOUSE_IN) begin
                    next_state = 9;
                end
            end
            9 : begin // wait device to set clock line low
                if (~CLK_MOUSE_IN) begin
                    next_state = 10;
                end
            end
            10 : begin // wait device to release data line and clock line
                if (DATA_MOUSE_IN & CLK_MOUSE_IN) begin
                    next_state = 0;
                    next_byteSent = 1'b1;
                end
            end
            default : begin
                next_state = 4'b0000;
                next_MSClkOutWE = 1'b0;
                next_MSDataOut = 1'b0;
                next_MSDataOutWE = 1'b0;
                next_sendCtr = 0;
                next_byteSent = 1'b0;
                next_byteToSend = 8'h00;
            end
        endcase
    end

    assign CLK_MOUSE_OUT_EN = curr_MSClkOutWE;
    assign DATA_MOUSE_OUT = curr_MSDataOut;
    assign DATA_MOUSE_OUT_EN = curr_MSDataOutWE;

    assign BYTE_SENT = curr_byteSent;

endmodule
