`include "header.svh"

module pipeline #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter CACHE_GROUP = 8,
    parameter CACHE_WAY = 8
) (
    input wire clk_i,
    input wire rst_i,

    // wishbone_IF
    output reg wb0_cyc_o,
    output reg wb0_stb_o,
    input wire wb0_ack_i,
    output reg [ADDR_WIDTH-1:0] wb0_adr_o,
    output reg [DATA_WIDTH-1:0] wb0_dat_o, // unused
    input wire [DATA_WIDTH-1:0] wb0_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb0_sel_o,
    output reg wb0_we_o,

    // wishbone_MEM
    output reg wb1_cyc_o,
    output reg wb1_stb_o,
    input wire wb1_ack_i,
    output reg [ADDR_WIDTH-1:0] wb1_adr_o,
    output reg [DATA_WIDTH-1:0] wb1_dat_o,
    input wire [DATA_WIDTH-1:0] wb1_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb1_sel_o,
    output reg wb1_we_o
);
// ---------- modules -----------

logic[31:0] if_pc_fetch;
logic[31:0] if_pc;
logic[31:0] id_pc;
logic[31:0] exe_pc;
logic[31:0] mem_pc;
logic[31:0] wb_pc;


// ????????
logic [31:0] if_instruct_buffer;
logic [31:0] if_instruct;
logic [31:0] id_instruct;

logic [2:0] id_instr_type;
logic [2:0] exe_instr_type;
logic [2:0] mem_instr_type;
logic [2:0] wb_instr_type;

logic [4:0] id_instr;
logic [4:0] exe_instr;
logic [4:0] mem_instr;
logic [4:0] wb_instr;


// if
logic if_fetching;
logic if_stalled;

// id
logic [4:0]  id_rs1_addr;
logic [4:0]  id_rs2_addr;
logic [4:0]  id_rd_addr;
logic [31:0] id_imm;
logic [3:0]  id_alu_op;


// exe
logic[31:0] forward_rdata_a;
logic[31:0] forward_rdata_b;

logic [3:0] exe_alu_op;
logic [31:0] exe_alu_y;
logic [31:0] exe_data_a;
logic [31:0] exe_data_b;

logic [4:0] exe_rd_addr;
logic [31:0] exe_mem_data;



// mem
logic mem_working;

logic mem_wb_we;
logic [4:0] mem_rd_addr;
logic [31:0] mem_wb_data;
logic [31:0] mem_addr;


// wb
logic [4:0] wb_waddr;
logic [31:0] wb_wdata;
logic wb_we;


// decoder ID
Decoder decoder(
    .instr(id_instruct),

    .instr_type(id_instr_type),
    .instruct(id_instr),
    .rs1(id_rs1_addr),
    .rs2(id_rs2_addr),
    .rd(id_rd_addr),
    .alu_op(id_alu_op),
    .imm(id_imm)
);    

// ALU EXE
ALU alu(
    .a(exe_data_a),
    .b(exe_data_b),
    .op(exe_alu_op),
    .y(exe_alu_y)
);



logic [31:0] pc_out;
logic pc_jump_reg;

logic [31:0] pc_predict;
logic predict_miss;


pc_mux pc_mux(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .if_ack_i(wb0_ack_i),
    .if_fetching(if_fetching),
    .cache_hit(cache_hit),
    .exe_pc(exe_pc),
    .alu_y_pc(exe_alu_y),
    .exe_branch(exe_branch),
    .pc_out(pc_out),
    .pc_jump_reg(pc_jump_reg),
    .pc_predict(pc_predict),
    .predict_miss(predict_miss || exe_instr == `INSTR_FENCEI)
);

logic exe_branch;

pc_predictor pc_predictor(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .if_pc(if_pc_fetch),
    .exe_pc(exe_pc),
    .alu_y_pc(exe_alu_y),
    .exe_instr_is_branch(exe_instr_type == `INSTR_B || exe_instr_type == `INSTR_J),
    .exe_branch(exe_branch),
    .exe_stall(stall_exe),

    .pc_predict(pc_predict),
    .predict_miss(predict_miss)
);

logic bubble_if;
logic stall_if;
logic bubble_id;
logic stall_id;
logic bubble_exe;
logic stall_exe;
logic bubble_mem;
logic stall_mem;
logic bubble_wb;
logic stall_wb;

hazard_controller hazard_controller(

    .if_fetching(if_fetching),
    .exe_branch_i(predict_miss || exe_instr == `INSTR_FENCEI),
    .mem_working(mem_working),

    .id_rs1_addr(id_rs1_addr),
    .id_rs2_addr(id_rs2_addr),
    .exe_rd_addr(exe_rd_addr),
    .exe_writeback_en(exe_instr_type == `INSTR_L),

    .stall_if_o(stall_if),
    .bubble_if_o(bubble_if),
    .stall_id_o(stall_id),
    .bubble_id_o(bubble_id),
    .stall_exe_o(stall_exe),
    .bubble_exe_o(bubble_exe),
    .stall_mem_o(stall_mem),
    .bubble_mem_o(bubble_mem),
    .stall_wb_o(stall_wb),
    .bubble_wb_o(bubble_wb)
);  

logic rf_we;
logic [4:0] rf_rs1;
logic [4:0] rf_rs2;
logic [31:0] rf_rdata_a;
logic [31:0] rf_rdata_b;

// regfile IF & WB
regfile rf(
    .clk(clk_i),
    .reset(rst_i),
    .waddr(wb_waddr),
    .wdata(wb_wdata),
    .we(rf_we),
    .raddr_a(rf_rs1),
    .raddr_b(rf_rs2),
    .rdata_a(rf_rdata_a),
    .rdata_b(rf_rdata_b)
);

assign rf_rs1 = id_rs1_addr;
assign rf_rs2 = id_rs2_addr;

// ??????????????????????????????????
always_comb begin
    if (id_rs1_addr == 5'b0) begin
        forward_rdata_a = 5'b0;
    end else if(exe_instr_type != `INSTR_S && exe_rd_addr == id_rs1_addr) begin
        if (exe_instr_type == `INSTR_J) begin
            forward_rdata_a = exe_pc + 4;
        end else begin
            forward_rdata_a = exe_alu_y;
        end
    end else if(mem_wb_we && mem_rd_addr == id_rs1_addr) begin
        forward_rdata_a = mem_wb_data;
    end else if(wb_we && wb_waddr == id_rs1_addr) begin
        forward_rdata_a = wb_wdata;
    end else begin
        forward_rdata_a = rf_rdata_a;
    end
end

always_comb begin
    if (id_rs2_addr == 5'b0) begin
        forward_rdata_b = 5'b0;
    end else if(exe_instr_type != `INSTR_S && exe_rd_addr == id_rs2_addr) begin
        if (exe_instr_type == `INSTR_J) begin
            forward_rdata_b = exe_pc + 4;
        end else begin
            forward_rdata_b = exe_alu_y;
        end
    end else if(mem_wb_we && mem_rd_addr == id_rs2_addr) begin
        forward_rdata_b = mem_wb_data;
    end else if(wb_we && wb_waddr == id_rs2_addr) begin
        forward_rdata_b = wb_wdata;
    end else begin
        forward_rdata_b = rf_rdata_b;
    end
end

logic [DATA_WIDTH-1:0] cache[7:0][7:0];
logic [26:0] cache_tag[7:0][7:0];
logic [3:0] cache_valid_num[7:0];
logic [7:0] cache_access_num[7:0][7:0];
logic [26:0] pc_tag;
logic [2:0] pc_group;
logic cache_hit;
logic [DATA_WIDTH-1:0] cache_data_select;
logic [3:0] cache_way_select;
logic [3:0] min_access_way[7:0];
logic [DATA_WIDTH-1:0] data_select;


assign pc_tag = if_pc_fetch[31:5];
assign pc_group = if_pc_fetch[4:2];

always_comb begin
    cache_hit = 0;
    cache_data_select = 32'h0;
    cache_way_select = 0;
    if(!if_fetching)begin
        for(int i=0; i<cache_valid_num[pc_group]; i=i+1)begin
            if(pc_tag==cache_tag[pc_group][i])begin
                cache_hit = 1;
                cache_data_select = cache[pc_group][i];
                cache_way_select = i;
            end
        end
    end
end

reg[7:0] min_count;
reg[2:0] min_index;
always_comb begin
    for (int i = 0; i < 8; i = i + 1) begin
        min_count = 8'hFF;  // ??????????
        min_index = 3'b000; // ??????????????
        for (int j = 0; j < 8; j = j + 1) begin
            if (cache_access_num[i][j] < min_count) begin
                min_count = cache_access_num[i][j];
                min_index = j;
            end
        end
        min_access_way[i] = min_index;
    end
end

// ---------- stages -----------


always_ff @ (posedge clk_i or posedge rst_i) begin
    // rest
    if (rst_i) begin
        // initialize outputs
        wb0_cyc_o <= 1'b0;
        wb0_stb_o <= 1'b0;
        wb0_adr_o <= 32'h0;
        wb0_dat_o <= 32'h0;
        wb0_sel_o <= 4'b1111;
        wb0_we_o <= 1'b0;

        wb1_cyc_o <= 1'b0;
        wb1_stb_o <= 1'b0;
        wb1_adr_o <= 32'h0;
        wb1_dat_o <= 32'h0;
        wb1_sel_o <= 4'b1111;
        wb1_we_o <= 1'b0;

        rf_we <= 1'b0;

        if_pc_fetch <= `PC_INIT;
        if_pc <= `PC_INIT;
        id_pc <= `PC_INIT;
        exe_pc <= `PC_INIT;
        mem_pc <= `PC_INIT;
        wb_pc <= `PC_INIT;

        if_instruct <= 32'h0;
        id_instruct <= 32'h0;

        if_fetching <= 1'b0;
        if_stalled <= 1'b0;

        exe_instr <= `INSTR_ADD;
        mem_instr <= `INSTR_ADD;
        wb_instr <= `INSTR_ADD;

        exe_instr_type <= `INSTR_I;
        mem_instr_type <= `INSTR_I;
        wb_instr_type <= `INSTR_I;

        exe_alu_op <= 4'b0000;

        exe_data_a <= 32'h0;
        exe_data_b <= 32'h0;
        exe_mem_data <= 32'h0;        
        exe_rd_addr <= 5'b0;


        mem_working <= 1'b0;
        mem_rd_addr <= 5'b0;
        mem_wb_we <= 1'b0;
        mem_rd_addr <= 5'b0;
        mem_wb_data <= 32'h0;
        mem_addr <= 32'h0;


        wb_waddr <= 5'b0;
        wb_wdata <= 32'h0;
        wb_we <= 1'b0;

        data_select <= 32'h0;
        for(int i = 0; i < CACHE_GROUP; i=i+1) begin
            for(int j = 0; j < CACHE_WAY; j=j+1) begin
                cache[i][j] <= 32'h0;
                cache_tag[i][j] <= 32'h0;
                cache_access_num[i][j] <= 0;
            end
            cache_valid_num[i] <= 0;
        end



    end else begin
        // i cache
        if(exe_instr == `INSTR_FENCEI) begin
            for(int i = 0; i < CACHE_GROUP; i=i+1) begin
                cache_valid_num[i] <= 0;
            end
        end

        // IF stage
        if(bubble_if) begin
            if_instruct <= `INSTR_NOP;
            if_pc <= 0;

        end if (!if_fetching && !if_stalled) begin  //ready
            if(cache_hit)begin
                if (!stall_if) begin
                    if_instruct_buffer <= cache_data_select;
                    if (predict_miss || exe_instr == `INSTR_FENCEI) begin
                        // abandon this instr
                        if_instruct <= `INSTR_NOP;
                        if_pc <= 0;
                    end else begin
                        cache_access_num[pc_group][cache_way_select] <= cache_access_num[pc_group][cache_way_select] + 1;
                        if_instruct <= cache_data_select;
                        if_pc <= if_pc_fetch;
                    end
                    if_pc_fetch <= pc_out;
                end
            end else begin
                wb0_cyc_o <= 1'b1;
                wb0_stb_o <= 1'b1;
                wb0_adr_o <= if_pc_fetch;
                if_fetching <= 1'b1;
                if (!stall_if) begin    
                    if_instruct <= `INSTR_NOP;
                    if_pc <= 0;
                end
            end


        end else if (!if_stalled) begin // fetching
            if(wb0_ack_i) begin     // fetch complete
                wb0_cyc_o <= 1'b0;
                wb0_stb_o <= 1'b0;
                if_fetching <= 1'b0;

                if_instruct_buffer <= wb0_dat_i;

                // update icache
                if(cache_valid_num[pc_group]<CACHE_WAY) begin
                    cache[pc_group][cache_valid_num[pc_group]]<= wb0_dat_i;
                    cache_tag[pc_group][cache_valid_num[pc_group]]<= pc_tag;
                    cache_valid_num[pc_group]<= cache_valid_num[pc_group]+1;
                    cache_access_num[pc_group][cache_valid_num[pc_group]]<= 1;
                end else begin
                    cache[pc_group][min_access_way[pc_group]]<= wb0_dat_i;
                    cache_tag[pc_group][min_access_way[pc_group]]<= pc_tag;
                    cache_access_num[pc_group][min_access_way[pc_group]]<= 1;
                end
        
                if (pc_jump_reg || predict_miss || exe_instr == `INSTR_FENCEI) begin
                // abandon this instr
                    if_instruct <= `INSTR_NOP;
                    if_pc <= 0;
                    if_pc_fetch <= pc_out;
                end else if (stall_if) begin
                    if_stalled <= 1;
                end else begin
                    if_instruct <= wb0_dat_i;
                    if_pc <= if_pc_fetch;
                    if_pc_fetch <= pc_out;
                end
            end else if(!stall_if) begin
                if_instruct <= `INSTR_NOP;
                if_pc <= 0;
            end
        end else begin  // stalled
            if (!stall_if) begin    // released
                if_stalled <= 0;
                if_instruct <= if_instruct_buffer;
                if_pc <= if_pc_fetch;
                if_pc_fetch <= pc_out;
            end
        end

        // IF-ID stage
        // bubble instruction add x0, x0, x0
        // 00000000000000000000000000110011
        if(bubble_id) begin
            id_instruct <= `INSTR_NOP;
            id_pc <= 32'b0;
        end else if (stall_id) begin
            
        end else begin        
            id_instruct <= if_instruct;
            id_pc <= if_pc;
        end

        // ID-EXE stage
        if(bubble_exe) begin
            exe_instr <= 32'h0;
            exe_instr_type <= `INSTR_I;

            exe_data_a <= 32'h0;
            exe_data_b <= 32'h0;

            exe_rd_addr <= 5'b0;
            exe_alu_op <= 4'b0000;
            exe_mem_data <= 32'h0;

            exe_branch <= 0;

            exe_pc <= 32'b0;

        end else if (stall_exe) begin
            
        end else begin
            exe_instr <= id_instr;
            exe_instr_type <= id_instr_type;  

            exe_rd_addr <= id_rd_addr;
            exe_alu_op <= id_alu_op;
            exe_pc <= id_pc;

            exe_branch <= 0;

            if(id_instr_type == `INSTR_R) begin
                exe_data_a <= forward_rdata_a;
                exe_data_b <= forward_rdata_b;

            end else if(id_instr_type == `INSTR_I) begin
                exe_data_a <= forward_rdata_a;
                exe_data_b <= id_imm;
            
            end else if(id_instr_type == `INSTR_S) begin
                // address = rs1 + imm
                // data = rs2
                exe_data_a <= forward_rdata_a;
                exe_data_b <= id_imm;
                exe_mem_data <= forward_rdata_b;

            end else if(id_instr_type == `INSTR_L) begin
                // address = rs1 + imm
                exe_data_a <= forward_rdata_a;
                exe_data_b <= id_imm;
                

            end else if(id_instr_type == `INSTR_U) begin
                // AUIPC
                if(id_instr == `INSTR_AUIPC) begin
                    exe_data_a <= id_pc;
                    exe_data_b <= id_imm;
                // LUI
                end else begin
                    exe_data_a <= 32'h0;
                    exe_data_b <= id_imm;
                end
            end else if(id_instr_type == `INSTR_J) begin
                exe_branch <= 1;
                case (id_instr)
                    `INSTR_JAL: exe_data_a <= id_pc;
                    `INSTR_JALR: exe_data_a <= forward_rdata_a;
                    default: exe_data_a <= id_pc;
                endcase
                exe_data_b <= id_imm;
        
            end else if (id_instr_type == `INSTR_B) begin
                case (id_instr)
                    `INSTR_BEQ: exe_branch <= (forward_rdata_a == forward_rdata_b);
                    `INSTR_BNE: exe_branch <= (forward_rdata_a != forward_rdata_b); 
                    default: exe_branch <= 0;
                endcase
                exe_data_a <= id_pc;
                exe_data_b <= id_imm;

            end else if(id_instr_type == `INSTR_EX) begin
                exe_data_a <= forward_rdata_a;
                // SBCLR
                if(id_instr == `INSTR_SBCLR) begin
                    exe_data_b <= ~ (32'b1 << (forward_rdata_b & 32'h1f));
                // ANDN, XNOR
                end else begin
                    exe_data_b <= ~forward_rdata_b;
                end 

            end else begin
                exe_data_a <= 32'h0;
                exe_data_b <= 32'h0;
            end
        end

        // EXE-MEM
        if(bubble_mem) begin
            mem_instr_type <= `INSTR_I;

            mem_wb_data <= 32'h0;
            mem_wb_we <= 0;
            mem_rd_addr <= 5'b0;

            mem_pc <= 32'b0;

        end else if (stall_mem) begin

        end else if(!mem_working) begin
            mem_pc <= exe_pc;

            mem_instr_type <= exe_instr_type;
            mem_instr <= exe_instr;
            mem_rd_addr <= exe_rd_addr;
            

            if(exe_instr_type == `INSTR_R || exe_instr_type == `INSTR_I || exe_instr_type == `INSTR_U || exe_instr_type == `INSTR_EX) begin
                mem_wb_data <= exe_alu_y;
                mem_wb_we <= 1;
                mem_working <= 1'b0;

            end else if(exe_instr_type == `INSTR_J) begin
                mem_wb_data <= exe_pc + 4;
                mem_wb_we <= 1;
                mem_working <= 1'b0;

            end else if(exe_instr_type == `INSTR_S) begin
                mem_wb_we <= 1'b0;
                // address: exe_alu_y data: exe_mem_data
                wb1_cyc_o <= 1'b1;
                wb1_stb_o <= 1'b1;
                wb1_we_o <= 1'b1;
                mem_working <= 1'b1;        
                wb1_adr_o <= exe_alu_y;     


                // sw
                if(exe_instr == `INSTR_SW)begin
                    wb1_sel_o <= 4'b1111;
                    wb1_dat_o <= exe_mem_data;
                end
                // sb
                else begin
                    case(exe_alu_y[1:0])
                        2'b00 : begin
                            wb1_dat_o[7:0] <= exe_mem_data[7:0];
                            wb1_sel_o <= 4'b0001;
                        end
                        2'b01 : begin 
                            wb1_dat_o[15:8] <= exe_mem_data[7:0];
                            wb1_sel_o <= 4'b0010;
                        end
                        2'b10 : begin
                            wb1_dat_o[23:16] <= exe_mem_data[7:0];
                            wb1_sel_o <= 4'b0100;
                        end
                        2'b11 : begin 
                            wb1_dat_o[31:24] <= exe_mem_data[7:0];
                            wb1_sel_o <= 4'b1000;
                        end
                    endcase
                end
                mem_addr <= exe_alu_y;

            end else if(exe_instr_type == `INSTR_L) begin

                mem_addr <= exe_alu_y;
                wb1_adr_o <= exe_alu_y;
                wb1_cyc_o <= 1'b1;
                wb1_stb_o <= 1'b1;
                
                wb1_we_o <= 1'b0;
                if(exe_instr == `INSTR_LW) begin
                    wb1_sel_o <= 4'b1111;
                end else begin
                    case (exe_alu_y[1:0])
                        2'b00 : wb1_sel_o <= 4'b0001;
                        2'b01 : wb1_sel_o <= 4'b0010;
                        2'b10 : wb1_sel_o <= 4'b0100;
                        2'b11 : wb1_sel_o <= 4'b1000;
                    endcase
                end
                mem_working <= 1'b1;
                // change to 1 when finishing reading memo
                mem_wb_we <= 0;
                
            end else begin
                mem_working <= 0;
                mem_wb_we <= 0;
            end

        end else begin
            if(wb1_ack_i) begin
                wb1_cyc_o <= 1'b0;
                wb1_stb_o <= 1'b0;
                wb1_we_o <= 1'b0;
                mem_working <= 1'b0;
                if(mem_instr_type == `INSTR_L) begin
                    mem_wb_we <= 1'b1;
                    if(mem_instr == `INSTR_LW) begin
                        mem_wb_data <= wb1_dat_i;
                    end else begin
                        case(mem_addr[1:0])
                            2'b00 : mem_wb_data <= {{24{wb1_dat_i[7]}}, wb1_dat_i[7:0]};
                            2'b01 : mem_wb_data <= {{24{wb1_dat_i[15]}}, wb1_dat_i[15:8]};
                            2'b10 : mem_wb_data <= {{24{wb1_dat_i[23]}}, wb1_dat_i[23:16]};
                            2'b11 : mem_wb_data <= {{24{wb1_dat_i[31]}}, wb1_dat_i[31:24]};
                        endcase
                    end
                end else begin
                    mem_wb_we <= 1'b0;
                end
            end
        end

        // MEM-WB
        if(bubble_wb) begin
            wb_instr <= 32'h0;
            wb_instr_type <= `INSTR_I;
            wb_waddr <= 5'b0;
            wb_wdata <= 32'h0;
            
            wb_we <= 1'b0;

            wb_pc <= 32'b0;
        end else if (stall_wb) begin
            wb_we <= 1'b0;
        end else begin
            wb_pc <= mem_pc;
            
            wb_instr <= mem_instr;
            wb_instr_type <= mem_instr_type;

            wb_waddr <= mem_rd_addr;
            wb_wdata <= mem_wb_data;
            wb_we <= mem_wb_we;

            if(mem_wb_we) begin
                rf_we <= 1'b1;
            end else begin
                rf_we <= 1'b0;
            end
        end
    end
end

endmodule