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
    input SWITCH,
    output [3:0] DISP_SEL_OUT,
    output [7:0] DISP_OUT
);


    // X, Y limits of mouse position. For VGA screen 160 * 120
    parameter [7:0] MouseLimitX = 160;
    parameter [7:0] MouseLimitY = 120;
    parameter [7:0] MouseLimitZ = 255;


    // Tri-state signals
    reg ClkMouseIn;
    wire ClkMouseOutEnTrans;

    wire DataMouseIn;
    wire DataMouseOutTrans;
    wire DataMouseOutEnTrans;

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


    wire [7:0] MouseStatusRaw;
    wire [7:0] MouseDxRaw;
    wire [7:0] MouseDyRaw;
    wire [7:0] MouseDzRaw;
    wire SendInterrupt;
    wire [3:0] MasterStateCode;
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
        .MOUSE_DZ(MouseDzRaw),
        .SEND_INTERRUPT(SendInterrupt),
        .MasterStateCode(MasterStateCode)
    );


// Pre-processing - handling of overflow and signs.
// More importantly, this keeps tabs on the actual X/Y
// location of the mouse.
    wire signed [8:0] MouseDx;
    wire signed [8:0] MouseDy;
    wire signed [8:0] MouseNewX;
    wire signed [8:0] MouseNewY;
    wire signed [8:0] MouseDz;
    wire signed [8:0] MouseNewZ;
    reg [3:0] MouseStatus;
    reg [7:0] MouseX;
    reg [7:0] MouseY;
    reg [7:0] MouseZ;

    // DX and DY are modified to take account of overflow and direction
    assign MouseDx = (MouseStatusRaw[6]) ? (MouseStatusRaw[4] ? {MouseStatusRaw[4],8'h00} : {MouseStatusRaw[4],8'hFF} ) : {MouseStatusRaw[4],MouseDxRaw[7:0]};
    assign MouseDy = (MouseStatusRaw[7]) ? (MouseStatusRaw[5] ? {MouseStatusRaw[5],8'h00} : {MouseStatusRaw[5],8'hFF} ) : {MouseStatusRaw[5],MouseDyRaw[7:0]};
    assign MouseDz = {MouseDzRaw[7], MouseDzRaw[7:0]};

    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            MouseStatus <= 0;
            MouseX <= MouseLimitX / 2;
            MouseY <= MouseLimitY / 2;
            MouseZ <= MouseLimitZ / 2;
        end
        else if (SendInterrupt) begin
            MouseStatus <= MouseStatusRaw[3:0];

            // X is modified based on DX with limits on max and min
            if (MouseNewX < 0) begin
                MouseX <= 0;
            end
            else if (MouseNewX > (MouseLimitX - 1)) begin
                MouseX <= MouseLimitX - 1;
            end
            else begin
                MouseX <= MouseNewX[7:0];
            end

            // Y is modified based on DY with limits on max and min
            if (MouseNewY < 0) begin
                MouseY <= 0;
            end
            else if (MouseNewY > (MouseLimitY - 1)) begin
                MouseY <= MouseLimitY - 1;
            end
            else begin
                MouseY <= MouseNewY[7:0];
            end

            //Z is modified based on DZ with limits on max and min
            if (MouseNewZ < 0) begin
                MouseZ <= 0;
            end
            else if (MouseNewZ > (MouseLimitZ - 1)) begin
                MouseZ <= MouseLimitZ - 1;
            end
            else begin
                MouseZ <= MouseNewZ[7:0];
            end
        end
    end

    assign MouseNewX = {1'b0, MouseX} + MouseDx;
    assign MouseNewY = {1'b0, MouseY} + MouseDy;
    assign MouseNewZ = {1'b0, MouseZ} + MouseDz;

// Pre-processing


// Display Select
    reg [4:0] dispIN0;
    reg [4:0] dispIN1;
    reg [4:0] dispIN2;
    reg [4:0] dispIN3;
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            dispIN0 <= 11000;
            dispIN1 <= 11000;
            dispIN2 <= 11000;
            dispIN3 <= 11000;
        end
        else begin
            if (SWITCH) begin
                dispIN0 <= MouseZ[7:4];
                dispIN1 <= MouseZ[3:0];
                dispIN2 <= MouseStatusRaw[7:4];
                dispIN3 <= MouseStatusRaw[3:0];
            end
            else begin
                dispIN0 <= MouseY[7:4];
                dispIN1 <= MouseY[3:0];
                dispIN2 <= MouseX[7:4];
                dispIN3 <= MouseX[3:0];
            end
        end
    end
// Display Select


// 7 Segment Display
    wire [4:0] dotBinIn;
    wire [3:0] segSelOut;
    wire [7:0] hexOut;

    wire trig_1kHz;
    wire [16:0] ctr_1kHz;
    wire trig_strobe;
    wire [1:0] ctr_strobe;

    Generic_counter # (
        .CTR_WIDTH(17),
        .CTR_MAX(99999)
    )
    Ctr1kHz (
        .CLK(CLK),
        .RESET(RESET),
        .ENABLE(1'b1),
        .OUT_TRIG(trig_1kHz),
        .OUT_CTR(ctr_1kHz)
    );

    Generic_counter # (
        .CTR_WIDTH(2),
        .CTR_MAX(3)
    )
    CtrStrobe (
        .CLK(CLK),
        .RESET(RESET),
        .ENABLE(trig_1kHz),
        .OUT_TRIG(trig_strobe),
        .OUT_CTR(ctr_strobe)
    );

    Mux4bit5 Multiplexer (
        .CONTROL(ctr_strobe),
        .IN0({1'b0, dispIN0}),
        .IN1({1'b0, dispIN1}),
        .IN2({1'b1, dispIN2}),
        .IN3({1'b0, dispIN3}),
        .OUT(dotBinIn)
    );

    Seg7Decoder Disp (
        .SEG_SELECT_IN(ctr_strobe),
        .BIN_IN(dotBinIn[3:0]),
        .DOT_IN(dotBinIn[4]),
        .SEG_SELECT_OUT(segSelOut),
        .HEX_OUT(hexOut)
    );
// 7 Segment Display


    assign DISP_SEL_OUT = segSelOut;
    assign DISP_OUT = hexOut;


    // ila_1 your_instance_name (
    //     .clk(CLK), // input wire clk
    
    
    //     .probe0(RESET), // input wire [0:0]  probe0  
    //     .probe1(CLK_MOUSE), // input wire [0:0]  probe1 
    //     .probe2(DATA_MOUSE), // input wire [0:0]  probe2 
    //     .probe3(ByteErrorCode), // input wire [1:0]  probe3 
    //     .probe4(MasterStateCode), // input wire [3:0]  probe4 
    //     .probe5(ByteToSendToMouse), // input wire [7:0]  probe5 
    //     .probe6(ByteRead) // input wire [7:0]  probe6
    // );

endmodule



module Seg7Decoder (
    input [1:0] SEG_SELECT_IN,
    input [3:0] BIN_IN,
    input DOT_IN,
    output reg [3:0] SEG_SELECT_OUT,
    output reg [7:0] HEX_OUT
);

    always @(BIN_IN) begin
        case (BIN_IN)
            4'b0000:    HEX_OUT[6:0] <= 7'b1000000; // 0
            4'b0001:    HEX_OUT[6:0] <= 7'b1111001; // 1
            4'b0010:    HEX_OUT[6:0] <= 7'b0100100; // 2
            4'b0011:    HEX_OUT[6:0] <= 7'b0110000; // 3
            
            4'b0100:    HEX_OUT[6:0] <= 7'b0011001; // 4
            4'b0101:    HEX_OUT[6:0] <= 7'b0010010; // 5
            4'b0110:    HEX_OUT[6:0] <= 7'b0000010; // 6
            4'b0111:    HEX_OUT[6:0] <= 7'b1111000; // 7

            4'b1000:    HEX_OUT[6:0] <= 7'b0000000; // 8
            4'b1001:    HEX_OUT[6:0] <= 7'b0011000; // 9
            4'b1010:    HEX_OUT[6:0] <= 7'b0001000; // A
            4'b1011:    HEX_OUT[6:0] <= 7'b0000011; // B
            
            4'b1100:    HEX_OUT[6:0] <= 7'b1000110; // C
            4'b1101:    HEX_OUT[6:0] <= 7'b0100001; // D
            4'b1110:    HEX_OUT[6:0] <= 7'b0000110; // E
            4'b1111:    HEX_OUT[6:0] <= 7'b0001110; // F
            
            default:    HEX_OUT[6:0] <= 7'b1111111; // off
        endcase
    end

    always @(DOT_IN) begin
        HEX_OUT[7] <= ~DOT_IN;
    end

    always @(SEG_SELECT_IN) begin
        case (SEG_SELECT_IN)
            2'b00:      SEG_SELECT_OUT <= 4'b1110; // rightmost
            2'b01:      SEG_SELECT_OUT <= 4'b1101;
            2'b10:      SEG_SELECT_OUT <= 4'b1011;
            2'b11:      SEG_SELECT_OUT <= 4'b0111; // leftmost
            default:    SEG_SELECT_OUT <= 4'b1111; // all off
        endcase
    end

endmodule



module Generic_counter # (
    parameter CTR_WIDTH = 4,
    parameter CTR_MAX = 9
)
(
    input CLK,
    input RESET,
    input ENABLE,
    output OUT_TRIG,
    output [(CTR_WIDTH - 1):0] OUT_CTR
);
    
    reg [(CTR_WIDTH - 1):0] tp_ctr;
    reg tp_trig;
    
    always @(posedge CLK) begin
        if (RESET) begin
            tp_ctr <= 0;
        end
        else begin
            if (ENABLE) begin
                if (tp_ctr == CTR_MAX) begin
                    tp_ctr <= 0;
                end
                else begin
                    tp_ctr <= tp_ctr + 1;
                end
            end
            else begin
                tp_ctr <= tp_ctr;
            end
        end
    end
    
    always @(posedge CLK) begin
        if (RESET) begin
            tp_trig <= 0;
        end
        else begin
            if (ENABLE) begin
                if (tp_ctr == CTR_MAX) begin
                    tp_trig <= 1;
                end
                else begin
                    tp_trig <= 0;
                end
            end
            else begin
                tp_trig <= 0;
            end
        end
    end
    
    assign OUT_CTR = tp_ctr;
    assign OUT_TRIG = tp_trig;

endmodule



module Mux4bit5 (
    input [1:0] CONTROL,
    input [4:0] IN0,
    input [4:0] IN1,
    input [4:0] IN2,
    input [4:0] IN3,
    output reg [4:0] OUT
);

    always @(CONTROL or IN0 or IN1 or IN2 or IN3) begin
        case (CONTROL)
            2'b00       :   OUT <= IN0;
            2'b01       :   OUT <= IN1;
            2'b10       :   OUT <= IN2;
            2'b11       :   OUT <= IN3;
            default     :   OUT <= 5'b00000;
        endcase
    end

endmodule
