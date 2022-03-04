`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.02.2022 00:16:27
// Design Name: 
// Module Name: MouseReceiver
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


module MouseReceiver (
    // Standard Inputs
    input CLK,
    input RESET,
    // Mouse IO
    input CLK_MOUSE_IN,
    input DATA_MOUSE_IN,
    // Control
    input READ_ENABLE,
    output [7:0] BYTE_READ,
    output [1:0] BYTE_ERROR_CODE,
    output BYTE_READY
);


    parameter T_TIMEOUT = 50000;

    reg CLK_MOUSE_SYNC; // sync mouse clock
    always @(posedge CLK) begin
        CLK_MOUSE_SYNC <= CLK_MOUSE_IN;
    end


    reg [2:0] curr_state;
    reg [2:0] next_state;
    reg [7:0] curr_MSShiftReg;
    reg [7:0] next_MSShiftReg;
    reg [3:0] curr_bitCtr;
    reg [3:0] next_bitCtr;
    reg curr_byteReceived;
    reg next_byteReceived;
    reg [1:0] curr_MSStatus;
    reg [1:0] next_MSStatus;
    reg [15:0] curr_timeoutCtr;
    reg [15:0] next_timeoutCtr;


    // Sequential
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            curr_state <= 3'b000;
            curr_MSShiftReg <= 8'h00;
            curr_bitCtr <= 0;
            curr_byteReceived <= 1'b0;
            curr_MSStatus <= 2'b00;
            curr_timeoutCtr <= 0;
        end
        else begin
            curr_state <= next_state;
            curr_MSShiftReg <= next_MSShiftReg;
            curr_bitCtr <= next_bitCtr;
            curr_byteReceived <= next_byteReceived;
            curr_MSStatus <= next_MSStatus;
            curr_timeoutCtr <= next_timeoutCtr;;
        end
    end

    // Combinational
    always @(*) begin
        next_state <= curr_state;
        next_MSShiftReg <= curr_MSShiftReg;
        next_bitCtr <= curr_bitCtr;
        next_byteReceived <= 1'b0;
        next_MSStatus <= curr_MSStatus;
        next_timeoutCtr <= curr_timeoutCtr + 1;

        case (curr_state)
            3'b000 : begin
                if (READ_ENABLE & CLK_MOUSE_SYNC & ~CLK_MOUSE_IN & ~DATA_MOUSE_IN) begin
                    next_state = 3'b001;
                    next_MSStatus = 2'b00;
                end
                next_bitCtr = 0;
            end
            3'b001 : begin
                if (curr_timeoutCtr == T_TIMEOUT) begin // 1ms timeout
                    next_state = 3'b000;
                end
                else if (curr_bitCtr == 8) begin
                    next_state = 3'b010;
                    next_bitCtr = 0;
                end
                else if (CLK_MOUSE_SYNC & ~CLK_MOUSE_IN) begin
                    next_MSShiftReg[6:0] = curr_MSShiftReg[7:1];
                    next_MSShiftReg[7] = DATA_MOUSE_IN;
                    next_bitCtr = curr_bitCtr + 1;
                    next_timeoutCtr = 0;
                end
            end
            3'b010 : begin
                if (curr_timeoutCtr == T_TIMEOUT) begin
                    next_state = 3'b000;
                end
                else if (CLK_MOUSE_SYNC & ~CLK_MOUSE_IN) begin
                    if (DATA_MOUSE_IN != (~^curr_MSShiftReg[7:0])) begin // parity bit error
                        next_MSStatus[0] = 1'b1;
                    end
                    next_bitCtr = 0;
                    next_state = 3'b011;
                    next_timeoutCtr = 0;
                end
            end
            3'b011 : begin
                if (curr_timeoutCtr == T_TIMEOUT) begin
                    next_state = 3'b000;
                end
                else if (CLK_MOUSE_SYNC & ~CLK_MOUSE_IN) begin
                    if (~DATA_MOUSE_IN) begin
                        next_MSStatus[1] = 1'b1;
                    end
                end
                next_bitCtr = 0;
                next_state = 3'b100;
                next_timeoutCtr = 0;
            end
            3'b100 : begin
                next_byteReceived = 1'b1;
                next_state = 3'b000;
                next_timeoutCtr = 0;
            end
            default: begin
                next_state = 3'b000;
                next_MSShiftReg = 8'h00;
                next_bitCtr = 0;
                next_byteReceived = 1'b0;
                next_MSStatus = 2'b00;
                next_timeoutCtr = 0;
            end
        endcase
    end


    assign BYTE_READY = curr_byteReceived;
    assign BYTE_READ = curr_MSShiftReg;
    assign BYTE_ERROR_CODE = curr_MSStatus;

endmodule
