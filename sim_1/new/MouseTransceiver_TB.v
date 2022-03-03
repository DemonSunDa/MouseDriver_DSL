`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.02.2022 23:46:03
// Design Name: 
// Module Name: MouseTransceiver_TB
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


module MouseTransceiver_TB (

);
    reg CLK;
    reg RESET;
    
    reg ClkMouseIn;
    wire ClkMouseOutEnTrans;

    wire DataMouseIn;
    wire DataMouseOutTrans;
    wire DataMouseOutEnTrans;
    
    wire SendByteToMouse;
    wire ByteSentToMouse;
    wire [7:0] ByteToSendToMouse;
    
    MouseTransmitter uut (
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

    
    initial begin
        CLK = 1'b0;
        forever #5 CLK = ~CLK;
    end
    
    initial begin
        ClkMouseIn = 1'b0;
        forever #50000 ClkMouseIn = ~ClkMouseIn;
    end
    
    initial begin
        RESET = 1'b1;
        DataMouseIn = 1'b1;
        #100
        RESET = 1'b0;
        #1000000
        SendByteToMouse = 1'b1;
        ByteToSendToMouse = 8'b10011001;
        #1000000;
        $finish;
    end
endmodule
