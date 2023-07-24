`timescale 1ns / 1ps
module motion_chart(
    input clk,
    input start,
    input stop,
    input store,
    input reset,
    output [3:0] sel,
    output [6:0] seg7
);
    wire clk_1ms,clk_100ms;
    wire SDsel, //输出 1 时为最好成绩记录的选择信号
    SDen, //输出 1 时为保存最好成绩记录的寄存器的使能信号
    DPsel, //输出 1 时为显示计时成绩记录的选择信号
    TMen, //输出 1 时为码表计时器使能信号
    TMrst, //输出 1 时为码表计时器复位信号
    NewRecord;
    wire[15:0] TM_dout,SD_dout;
    clk_div_1ms u_clk_div_1ms(.clk_in(clk), .clk_out(clk_1ms));
    clk_div_100ms u_clk_div_100ms(.clk_in(clk), .clk_out(clk_100ms));
    CU u_cu(.clk(clk_100ms), .start(start), .stop(stop), .store(store), .reset(reset), .NewRecord(TM_dout<SD_dout),
        .SDsel(SDsel), .SDen(SDen), .DPsel(DPsel), .TMen(TMen), .TMrst(TMrst));
    BCDcounter u_cnt(.clk(clk_100ms), .en(TMen), .rst(TMrst), .Q(TM_dout));
    Register u_reg(.clk(clk_100ms), .en(SDen), .din(SDsel?TM_dout:16'h9999), .dout(SD_dout));
    Display u_dis(.clk_1ms(clk_1ms), .din(DPsel?TM_dout:SD_dout), .sel(sel), .seg7(seg7));
endmodule

module Display(
    input clk_1ms,
    input[15:0] din,
    output reg[3:0] sel,
    output reg[6:0] seg7
);
    reg[1:0] s = 0;
    reg[3:0] digit = 0;
    always@(*)begin
        case(s)
            0:digit <= din[3:0];
            1:digit <= din[7:4];
            2:digit <= din[11:8];
            3:digit <= din[15:12];
            default:digit <= din[3:0];
        endcase
    end
    always@(*)begin
        case(digit)
            0: seg7 <= 7'h3f;
            1: seg7 <= 7'h06;
            2: seg7 <= 7'h5b;
            3: seg7 <= 7'h4f;
            4: seg7 <= 7'h66;
            5: seg7 <= 7'h6d;
            6: seg7 <= 7'h7d;
            7: seg7 <= 7'h07;
            8: seg7 <= 7'h7f;
            9: seg7 <= 7'h6f;
            'hA: seg7 <= 7'h77;
            'hB: seg7 <= 7'h7c;
            'hC: seg7 <= 7'h39;
            'hD: seg7 <= 7'h5e;
            'hE: seg7 <= 7'h79;
            'hF: seg7 <= 7'h71;
            default: seg7 <= 7'h3f;
        endcase
    end
    always@(*)begin
        sel <= 4'b0000;
        sel[s] <= 1;
    end
    always@(posedge clk_1ms) begin
        s <= s+1;
    end
endmodule

module Register(
    input clk, en,
    input[15:0] din,
    output reg[15:0] dout
);
    always @(posedge clk) begin
        if(en)
            dout<=din;
        else
            dout<=dout;
    end
endmodule

module BCDcounter(
    input clk,en,rst,
    output reg[15:0] Q=16'b0
);
    always @(posedge clk or posedge rst)begin
        if(rst == 1)
            Q<=1'b0;
        else if(en == 1'b0)
            Q=Q;
        else if(en == 1'b1)begin
            if(Q[3:0]<4'd9)
                Q[3:0]<=Q[3:0]+1'b1;
            else begin
                Q[3:0]<=1'b0;
                if(Q[7:4]<4'd5)
                    Q[7:4]<=Q[7:4]+1'b1;
                else begin
                    Q[7:4]<=1'b0;
                    if(Q[11:8]<=4'd9)
                        Q[11:8]<=Q[11:8]+1'b1;
                    else begin
                        Q[11:8]<=1'b0;
                        if(Q[15:12]<4'd5)
                            Q[15:12]<=Q[15:12]+1'b1;
                        else begin
                            Q[15:12]<=1'b0;
                        end
                    end
                end
            end
        end
    end
endmodule

module CU(
    input clk,start,stop,store,reset,NewRecord,
    output reg SDsel,SDen,DPsel,TMen,TMrst
);
    reg[5:0] cs=6'b0;
    reg[5:0] ns=6'b0;
    parameter Reset=6'b000001,Count=6'b000010,Stop=6'b000100,Store=6'b001000,Display = 6'b010000,Restart=6'b100000;
    always @(posedge clk or posedge reset) begin // 状态跳转
        if(reset) cs<=Reset;
        else cs<=ns;
    end
    always @(start or stop or store or reset or NewRecord) // 状态转换
    begin
        case(cs)
            Reset:begin
                if(start) ns=Count;
                else if(store) ns=Display;
                else ns=Reset;
            end
            Count:begin
                if(stop) ns=Stop;
                else if(reset) ns=Reset;
                else ns=Count;
            end
            Stop:begin
                if(store && NewRecord) ns = Store;
                else if(store && !NewRecord) ns = Display;
                else if(reset) ns = Reset;
                else if(start) ns = Restart;
                else ns = Stop;
            end
            Store: ns = Display;
            Display:begin
                if(start) ns = Restart;
                else if(reset) ns = Reset;
                else ns = Display;
            end
            Restart: ns = Count;
            default: ns = Reset;
        endcase
    end
    always @(posedge clk)begin // 产生输出信号
        if(cs==Reset){SDsel,SDen,DPsel,TMen,TMrst}<=5'b01101;
        else if(cs==Count){SDsel,SDen,DPsel,TMen,TMrst}<=5'b00110;
        else if(cs==Stop){SDsel,SDen,DPsel,TMen,TMrst}<=5'b00100;
        else if(cs==Store){SDsel,SDen,DPsel,TMen,TMrst}<=5'b11000;
        else if(cs==Display){SDsel,SDen,DPsel,TMen,TMrst}<=5'b00000;
        else if(cs==Restart){SDsel,SDen,DPsel,TMen,TMrst}<=5'b00101;
        else {SDsel,SDen,DPsel,TMen,TMrst}<=5'b01101;
    end
endmodule

module clk_div_1ms(
    input clk_in,
    output reg clk_out
);
    reg[32:0] clk_cnt=0;
    always @(posedge clk_in)
    begin
        if(clk_cnt == 49999)
            begin
                clk_out = ~clk_out;
                clk_cnt = 0;
            end
        else
            clk_cnt = clk_cnt + 1;
    end
endmodule

module clk_div_100ms(
    input clk_in,
    output reg clk_out
);
    reg[32:0] clk_cnt=0;
    always @(posedge clk_in)
    begin
        if(clk_cnt == 4999999)
            begin
                clk_out = ~clk_out;
                clk_cnt = 0;
            end
        else
            clk_cnt = clk_cnt + 1;
    end
endmodule


