// `include "package.sv"


module hazard_controller(
    // ??????
    // stall ????????, bubble ???????????
    output reg stall_if_o,
    output reg bubble_if_o,
    output reg stall_id_o,
    output reg bubble_id_o,
    output reg stall_exe_o,
    output reg bubble_exe_o,
    output reg stall_mem_o,
    output reg bubble_mem_o,
    output reg stall_wb_o,
    output reg bubble_wb_o,

    input wire [4:0] id_rs1_addr,
    input wire [4:0] id_rs2_addr,
    input wire [4:0] exe_rd_addr,
    input wire exe_writeback_en,

    input wire if_fetching,
    input wire mem_working,
    input wire exe_branch_i
);

    always_comb begin
        stall_if_o = 1'b0;
        bubble_if_o = 1'b0;
        stall_id_o = 1'b0;
        bubble_id_o = 1'b0;
        stall_exe_o = 1'b0;
        bubble_exe_o = 1'b0;
        stall_mem_o = 1'b0;
        bubble_mem_o = 1'b0;
        stall_wb_o = 1'b0;
        bubble_wb_o = 1'b0;

        if (mem_working) begin
            stall_if_o = 1'b1;
            stall_id_o = 1'b1;
            stall_exe_o = 1'b1;
            // bubble_mem_o = 1'b1;
        end else if (exe_branch_i) begin
            bubble_if_o = 1'b1;
            bubble_id_o = 1'b1;
            bubble_exe_o = 1'b1;
        end else if (
            exe_writeback_en && exe_rd_addr != 0 && (
                id_rs1_addr == exe_rd_addr ||
                id_rs2_addr == exe_rd_addr
            )
        ) begin
            // data conflict (read after write)
            stall_if_o = 1'b1;
            stall_id_o = 1'b1;
            bubble_exe_o = 1'b1;
        end
    end
    

endmodule