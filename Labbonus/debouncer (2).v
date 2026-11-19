module debouncer (
    input  wire clk,
    input  wire rst,
    input  wire btn_in,
    output reg  btn_out,
    output reg  btn_pulse
);
    localparam COUNT_MAX = 19'd500000; // 10ms a 50MHz

    reg [18:0] count;
    reg        btn_sync_0;
    reg        btn_sync_1;
    reg        btn_out_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            btn_sync_0   <= 1'b1;
            btn_sync_1   <= 1'b1;
            btn_out      <= 1'b1;
            btn_out_prev <= 1'b1;
            btn_pulse    <= 1'b0;
            count        <= 19'd0;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;

            if (btn_sync_1 != btn_out) begin
                if (count < COUNT_MAX) begin
                    count <= count + 19'd1;
                end else begin
                    btn_out <= btn_sync_1;
                    count   <= 19'd0;
                end
            end else begin
                count <= 19'd0;
            end

            btn_out_prev <= btn_out;
            btn_pulse    <= (btn_out_prev == 1'b1) && (btn_out == 1'b0);
        end
    end
endmodule