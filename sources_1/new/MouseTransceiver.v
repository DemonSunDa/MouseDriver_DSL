`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.02.2022 00:15:22
// Design Name: 
// Module Name: MouseTransceiver
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


module MouseTransceiver (
    // Standard Inputs
    input CLK,
    input RESET,
    // IO Mouse
    inout CLK_MOUSE,
    inout DATA_MOUSE,
    // Mouse Data Information
    // output [3:0] MouseStatus,
    // output [7:0] MouseX,
    // output [7:0] MouseY
    output [7:0] MouseStatusByte,
    output [7:0] MouseDXByte,
    output [7:0] MouseDYByte
);


    // X, Y limits of mouse position. For VGA screen 160 * 120
    parameter [7:0] MouseLimitX = 160;
    parameter [7:0] MouseLimitY = 120;


    // Tri-state signals
    reg ClkMouseIn;
    wire ClkMouseOutEnTrans;

    wire DataMouseIn;
    wire DataMouseOutTrans;
    wire DataMouseOutEnTrans;

    // CLK input
    assign ClkMouseIn = CLK_MOUSE;
    // CLK output
    assign CLK_MOUSE = ClkMouseOutEnTrans ? 1'b0 : 1'bz;
    // Data input
    assign DataMouseIn = DATA_MOUSE;
    // Data output
    assign DATA_MOUSE = DataMouseOutEnTrans ? DataMouseOutTrans : 1'bz;


    // Filter the incoming mouse clock to make sure it is stable
    reg [7:0] MouseClkFilter;
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            ClkMouseIn <= 1'b0;
        end
        else begin
            MouseClkFilter[7:1] <= MouseClkFilter[6:0];
            MouseClkFilter[0] <= CLK_MOUSE;

            // wait for 8 cycles and test if all the CLK inputs are the same
            if (ClkMouseIn & (MouseClkFilter == 8'h00)) begin
                ClkMouseIn <= 1'b0;
            end
            else if (~ClkMouseIn & (MouseClkFilter == 8'hFF)) begin
                ClkMouseIn <= 1'b1;
            end
        end
    end


    wire SendByteToMouse;
    wire ByteSentToMouse;
    wire [7:0] ByteToSendToMouse;
    MouseTransmitter T (
        // Standard Inputs
        .CLK(CLK),
        .RESET(RESET),
        // Mouse IO
        .CLK_MOUSE_IN(ClkMouseIn),
        .CLK_MOUSE_OUT_EN(ClkMouseOutEnTrans),
        .DATA_MOUSE_IN(DataMouseIn),
        .DATA_MOUSE_OUT(DataMouseOutTrans),
        .DATA_MOUSE_OUT_EN(DataMouseOutEnTrans),
        // Control
        .SEND_BYTE(SendByteToMouse),
        .BYTE_TO_SEND(ByteToSendToMouse),
        .BYTE_SENT(ByteSentToMouse)
    );


    wire ReadEnable;
    wire [7:0] ByteRead;
    wire [1:0] ByteErrorCode;
    wire ByteReady;
    MouseReceiver R (
        // Standard Inputs
        .CLK(CLK),
        .RESET(RESET),
        // Mouse IO
        .CLK_MOUSE_IN(ClkMouseIn),
        .DATA_MOUSE_IN(DataMouseIn),
        // Control
        .READ_ENABLE(ReadEnable),
        .BYTE_READ(ByteRead),
        .BYTE_ERROR_CODE(ByteErrorCode),
        .BYTE_READY(ByteReady)
    );


    // wire [7:0] MouseStatusRaw;
    // wire [7:0] MouseDxRaw;
    // wire [7:0] MouseDyRaw;
    reg [7:0] MouseStatusRaw;
    reg [7:0] MouseDxRaw;
    reg [7:0] MouseDyRaw;
    wire SendInterrupt;
    MouseMasterSM MSM (
        // Standard Inputs
        .CLK(CLK),
        .RESET(RESET),
        // Transmitter Interface
        .SEND_BYTE(SendByteToMouse),
        .BYTE_TO_SEND(ByteToSendToMouse),
        .BYTE_SENT(ByteSentToMouse),
        // Receiver Interface
        .READ_ENABLE(ReadEnable),
        .BYTE_READ(ByteRead),
        .BYTE_ERROR_CODE(ByteErrorCode),
        .BYTE_READY(ByteReady),
        // Data Registers
        .MOUSE_STATUS(MouseStatusRaw),
        .MOUSE_DX(MouseDxRaw),
        .MOUSE_DY(MouseDyRaw),
        .SEND_INTERRUPT(SendInterrupt)
    );


    assign MouseStatusByte = MouseStatusRaw;
    assign MouseDXByte = MouseDxRaw;
    assign MouseDYByte = MouseDyRaw;

endmodule
