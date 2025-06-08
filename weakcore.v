// SPDX-License-Identifier: MPL-2.0
/*
 * My first step on digital logic design: a small state-machine-based RV32I
 * core.
 *
 * Copyright (c) 2025 Yao Zi <ziyao@disroot.org>
 */

module weakcore(
	input wire clk, input wire rst,

	input wire [31:0] bus_in,
	output wire [31:0] bus_out,
	output wire [31:0] bus_addr,
	output wire bus_req,
	input wire bus_ack,
	output wire bus_wr,
	output wire [3:0] bus_wr_mask);

	/* ==================== Register Heap ==================== */

	reg [31:0] regs [0:31];

	always @ (posedge clk) begin
		if (~rst)
			regs[0] <= 32'h0;
	end

	reg [4:0] stage_state;
	wire stage_if = stage_state[0];
	wire stage_id = stage_state[2];
	wire stage_exe = stage_state[3];
	wire stage_wb = stage_state[4];
	wire ready_if;
	wire ready_exe;
	wire [4:0] stage_ready = { 1'b1, ready_exe, 1'b1, 1'b1, ready_if };

	always @ (posedge clk) begin
		if (~rst)
			stage_state <= 5'b0001;
		else if (|(stage_ready & stage_state))
			stage_state <= { stage_state[3:0], stage_state[4] };
	end

	/* ================= Instruction fetch ======================== */
	reg [31:0] pc;
	reg [31:0] instr_pc;
	reg [31:0] instr;
	always @ (posedge clk) begin
		if (~rst) begin
			pc <= 32'h0;
		end else if (stage_if & bus_ack) begin
			instr_pc <= pc;
			pc <= pc + 32'd4;
			instr <= bus_in;
		end
	end

	assign ready_if	= bus_ack;

	/* ===================== Decode =============================== */
	/* RISC-V instruction formats */
	wire [6:0] instr_opcode = instr[6:0];
	wire [2:0] instr_func3 = instr[14:12];
	wire [6:0] instr_func7 = instr[31:25];

	wire is_cond_branch	= instr_opcode == 7'b1100011;
	wire is_load		= instr_opcode == 7'b0000011;
	wire is_store		= instr_opcode == 7'b0100011;
	wire is_imm_arith	= instr_opcode == 7'b0010011;
	wire is_reg_arith	= instr_opcode == 7'b0110011;
	wire is_lui		= instr_opcode == 7'b0110111;
	wire is_auipc		= instr_opcode == 7'b0010111;
	wire is_jal		= instr_opcode == 7'b1101111;
	wire is_jalr		= instr_opcode == 7'b1100111;

	wire is_beq	= is_cond_branch && instr_func3 == 3'b000;
	wire is_bne	= is_cond_branch && instr_func3 == 3'b001;
	wire is_blt	= is_cond_branch && instr_func3 == 3'b100;
	wire is_bge	= is_cond_branch && instr_func3 == 3'b101;
	wire is_bltu	= is_cond_branch && instr_func3 == 3'b110;
	wire is_bgeu	= is_cond_branch && instr_func3 == 3'b111;

	wire is_addi	= is_imm_arith && instr_func3 == 3'b000;
	wire is_slti	= is_imm_arith && instr_func3 == 3'b010;
	wire is_sltiu	= is_imm_arith && instr_func3 == 3'b011;
	wire is_xori	= is_imm_arith && instr_func3 == 3'b100;
	wire is_ori	= is_imm_arith && instr_func3 == 3'b110;
	wire is_andi	= is_imm_arith && instr_func3 == 3'b111;

	wire is_slli	= is_imm_arith && instr_func3 == 3'b001;
	wire is_srli	= is_imm_arith && instr_func3 == 3'b101 &&
			  instr_func7 == 7'b0000000;
	wire is_srai	= is_imm_arith && instr_func3 == 3'b101 &&
			  instr_func7 == 7'b0100000;
	wire is_imm_shift = is_slli | is_srli | is_srai;

	wire is_add	= is_reg_arith && instr_func3 == 3'b000 &&
			  instr_func7 == 7'b0000000;
	wire is_sub	= is_reg_arith && instr_func3 == 3'b000 &&
			  instr_func7 == 7'b0100000;
	wire is_sll	= is_reg_arith && instr_func3 == 3'b001 &&
			  instr_func7 == 7'b0000000;
	wire is_slt	= is_reg_arith && instr_func3 == 3'b010 &&
			  instr_func7 == 7'b0000000;
	wire is_sltu	= is_reg_arith && instr_func3 == 3'b011 &&
			  instr_func7 == 7'b0000000;
	wire is_xor	= is_reg_arith && instr_func3 == 3'b100 &&
			  instr_func7 == 7'b0000000;
	wire is_srl	= is_reg_arith && instr_func3 == 3'b101 &&
			  instr_func7 == 7'b0000000;
	wire is_sra	= is_reg_arith && instr_func3 == 3'b101 &&
			  instr_func7 == 7'b0100000;
	wire is_or	= is_reg_arith && instr_func3 == 3'b110 &&
			  instr_func7 == 7'b0000000;
	wire is_and	= is_reg_arith && instr_func3 == 3'b111 &&
			  instr_func7 == 7'b0000000;
	wire is_reg_shift = is_sll | is_srl | is_sra;

	wire is_lb	= is_load && instr_func3 == 3'b000;
	wire is_lh	= is_load && instr_func3 == 3'b001;
	wire is_lw	= is_load && instr_func3 == 3'b010;
	wire is_lbu	= is_load && instr_func3 == 3'b100;
	wire is_lhu	= is_load && instr_func3 == 3'b101;

	wire is_sb	= is_store && instr_func3 == 3'b000;
	wire is_sh	= is_store && instr_func3 == 3'b001;
	wire is_sw	= is_store && instr_func3 == 3'b010;

	wire [4:0] instr_rd	= instr[11:7];
	wire [4:0] instr_rs1	= instr[19:15];
	wire [4:0] instr_rs2	= instr[24:20];

	wire [31:0] instr_i_imm = {{20{instr[31]}}, instr[31:20]};
	wire [31:0] instr_s_imm = {{20{instr[31]}}, instr[31:25], instr_rd};
	wire [31:0] instr_b_imm =
		{{19{instr[31]}},
		 instr[31], instr[7], instr[30:25], instr[11:8],
		 1'b0 };
	wire [31:0] instr_u_imm = {instr[31:12], 12'b0};
	wire [31:0] instr_j_imm =
		{{11{instr[31]}},
		 instr[31], instr[19:12], instr[20], instr[30:21],
		 1'b0};

	wire [4:0] instr_shift_shamt = instr_rs2;

	// 2 source registers, 0 immediate
	wire is_r_type = is_reg_arith | is_imm_shift;
	// 1 source registers, 1 immediate, no destination, 1 address register
	wire is_s_type = is_store;
	wire is_b_type = is_cond_branch;
	// 1 source register, 1 immediate
	wire is_i_type = (is_imm_arith & ~is_imm_shift) | is_load | is_jalr;
	// 0 source register, 1 immediate
	wire is_u_type = is_lui | is_auipc;
	wire is_j_type = is_jal;

	wire is_reg_arg1 = is_r_type | is_s_type | is_b_type | is_i_type;
	wire is_reg_arg2 = is_r_type | is_s_type | is_b_type;
	// In B-Type, IMMs are not for operands but for addressing
	wire is_with_imm = is_i_type | is_u_type | is_j_type;

	wire [31:0] instr_imm = ({32{is_s_type}} & instr_s_imm) |
				({32{is_b_type}} & instr_b_imm) |
				({32{is_i_type}} & instr_i_imm) |
				({32{is_u_type}} & instr_u_imm) |
				({32{is_j_type}} & instr_j_imm);

	/* How to execute the operation */
	wire op_add_tmp		= is_add | is_addi | is_lui | is_auipc;
	wire op_sub_tmp		= is_sub;
	wire op_load_tmp	= is_load;
	wire op_store_tmp	= is_store;
	wire op_cmp_less_tmp	= is_blt | is_slti | is_slt |
				  is_bge;
	wire op_cmp_less_u_tmp	= is_sltiu | is_sltu | is_bltu |
				  is_bgeu;
	wire op_cmp_eq_tmp	= is_beq |
				  is_bne;
	wire op_xor_tmp		= is_xori | is_xor;
	wire op_or_tmp		= is_ori | is_or;
	wire op_and_tmp		= is_andi | is_and;
	wire op_shift_left_tmp	= is_slli | is_sll;
	wire op_shift_right_l_tmp = is_srli | is_srl;
	wire op_shift_right_a_tmp = is_srai | is_sra;

	wire [31:0] op_arg1_tmp = ({32{is_reg_arg1}} & regs[instr_rs1]) |
				  ({32{is_auipc}} & instr_pc);
	wire [31:0] op_arg2_tmp = ({32{is_reg_arg2}} & regs[instr_rs2]) |
				  ({32{is_with_imm}} & instr_imm);

	wire [4:0] op_shamt_tmp = ({5{is_imm_shift}} & instr_shift_shamt) |
				  ({5{is_reg_shift}} & regs[instr_rs2][4:0]);

	wire op_mem_1b_tmp = is_lb | is_lbu | is_sb;
	wire op_mem_2b_tmp = is_lh | is_lhu | is_sh;
	wire op_mem_4b_tmp = is_lw | is_sw;
	wire op_mem_signext_tmp = is_lb | is_lh;

	wire [31:0] op_addr_base_tmp = ({32{is_load}} & regs[instr_rs1])  |
				       ({32{is_store}} & regs[instr_rs1]) |
				       ({32{is_jalr}} & regs[instr_rs1])  |
				       ({32{is_cond_branch}} & instr_pc)  |
				       ({32{is_jal}} & instr_pc);
	wire [31:0] op_addr_disp_tmp = instr_imm;
	wire [31:0] op_addr_tmp = op_addr_base_tmp + op_addr_disp_tmp;

	/* How to process the result in writeback stage */
	wire op_wb_tmp = is_imm_arith | is_reg_arith | is_load |
			 is_lui | is_auipc;
	wire op_cond_jump_tmp = is_cond_branch;
	wire op_expected_res_tmp = is_bne | is_bge | is_bgeu ? 1'b0 : 1'b1;
	wire op_jump_tmp = is_jal | is_jalr;

	reg op_add, op_sub;
	reg op_load, op_store;
	reg op_cmp_less, op_cmp_less_u, op_cmp_eq;
	reg op_xor, op_or, op_and;
	reg op_shift_left, op_shift_right_l, op_shift_right_a;
	reg [31:0] op_arg1;
	reg [31:0] op_arg2;
	reg [4:0] op_shamt;
	reg op_mem_1b, op_mem_2b, op_mem_4b;
	reg op_mem_signext;
	reg [31:0] op_addr;

	reg op_wb, op_cond_jump, op_expected_res, op_jump;

	always @ (posedge clk) begin
		if (stage_id) begin
			op_add <= op_add_tmp;
			op_sub <= op_sub_tmp;
			op_load <= op_load_tmp;
			op_store <= op_store_tmp;
			op_cmp_less <= op_cmp_less_tmp;
			op_cmp_less_u <= op_cmp_less_u_tmp;
			op_cmp_eq <= op_cmp_eq_tmp;
			op_xor <= op_xor_tmp;
			op_or <= op_or_tmp;
			op_and <= op_and_tmp;
			op_shift_left <= op_shift_left_tmp;
			op_shift_right_l <= op_shift_right_l_tmp;
			op_shift_right_a <= op_shift_right_a_tmp;
			op_arg1 <= op_arg1_tmp;
			op_arg2 <= op_arg2_tmp;
			op_shamt <= op_shamt_tmp;
			op_mem_1b <= op_mem_1b_tmp;
			op_mem_2b <= op_mem_2b_tmp;
			op_mem_4b <= op_mem_4b_tmp;
			op_mem_signext <= op_mem_signext_tmp;
			op_addr <= op_addr_tmp;
			op_wb <= op_wb_tmp;
			op_cond_jump <= op_cond_jump_tmp;
			op_expected_res <= op_expected_res_tmp;
			op_jump <= op_jump_tmp;
		end
	end

	/* =========================== Execution ====================== */
	reg [31:0] op_result;

	wire exe_adder_submode = op_cmp_less | op_cmp_less_u | op_sub;
	wire [31:0] exe_adder_src1 = op_arg1;
	wire [31:0] exe_adder_src2 = ({32{op_add}} & op_arg2)		|
				     ({32{exe_adder_submode}} & ~op_arg2);
	wire exe_adder_cin = exe_adder_submode;
	wire exe_adder_cout;
	wire [31:0] exe_adder_res;
	assign {exe_adder_cout, exe_adder_res} =
		exe_adder_src1 + exe_adder_src2 + {{31'b0, exe_adder_cin}};

	wire exe_cmp_less =
		(op_arg1[31] & ~op_arg2[31])	|
		(~(op_arg1[31] ^ op_arg2[31]) & exe_adder_res[31]);
	wire exe_cmp_less_u = ~exe_adder_cout;
	wire exe_cmp_eq = op_arg1 == op_arg2;

	wire [31:0] exe_xor = op_arg1 ^ op_arg2;
	wire [31:0] exe_or = op_arg1 | op_arg2;
	wire [31:0] exe_and = op_arg1 & op_arg2;

	wire [31:0] exe_shift_left	= op_arg1 << op_shamt;
	wire [31:0] exe_shift_right_l	= op_arg1 >> op_shamt;
	wire [31:0] exe_shift_right_a	= $signed(op_arg1) >>> op_shamt;

	wire exe_bus_req = op_load | op_store;
	wire exe_bus_wr = op_store;

	wire [31:0] exe_load_mask = ({24'b0, {8{op_mem_1b}}})	|
				    ({16'b0, {16{op_mem_2b}}})	|
				    ({32{op_mem_4b}});
	wire [4:0] exe_mem_shift = {op_addr[1:0], 3'b000};
	wire [31:0] exe_load_data = (bus_in >> exe_mem_shift) & exe_load_mask;
	wire [31:0] exe_load_res = exe_load_data | (op_mem_signext ?
		{{24{op_mem_1b & exe_load_data[7]}}, 8'b0}	|
		{{16{op_mem_2b & exe_load_data[15]}}, 16'b0} : 0);
	wire [31:0] exe_bus_out = op_arg2 << exe_mem_shift;
	wire [3:0] exe_bus_wr_mask =
		({3'b0, op_mem_1b}		|
		 {2'b0, {2{op_mem_2b}}}		|
		 {4{op_mem_4b}}) << op_addr[1:0];

	wire [31:0] op_tmp_result =
		({32{op_add}} & exe_adder_res)				|
		({32{op_sub}} & exe_adder_res)				|
		({32{op_cmp_less}} & {{31'b0, exe_cmp_less}})		|
		({32{op_load}} & exe_load_res)				|
		({32{op_cmp_less_u}} & {{31'b0, exe_cmp_less_u}})	|
		({32{op_xor}} & exe_xor)				|
		({32{op_or}} & exe_or)					|
		({32{op_and}} & exe_and)				|
		({32{op_shift_left}} & exe_shift_left)			|
		({32{op_shift_right_l}} & exe_shift_right_l)		|
		({32{op_shift_right_a}} & exe_shift_right_a)		|
		({32{op_cmp_eq}} & {{31'b0, exe_cmp_eq}});

	assign ready_exe = (~op_load & ~op_store) | bus_ack;


	always @ (posedge clk) begin
		if (~rst)
			op_result <= 32'h0;
		else if (stage_exe)
			op_result <= op_tmp_result;
	end

	/* ========================== Write back ====================== */
	always @ (posedge clk) begin
		if (stage_wb & op_wb & (|instr_rd)) begin
			regs[instr_rd] <= op_result;
		end

		if (stage_wb & op_cond_jump &
		    op_result[0] == op_expected_res) begin
			pc <= op_addr;
		end

		if (stage_wb & op_jump) begin
			if (|instr_rd)
				regs[instr_rd] <= pc;	// Return address
			pc <= op_addr;
		end
	end

	/* ========================== Bus control ====================== */
	assign bus_req	= stage_if | (stage_exe & exe_bus_req);
	assign bus_addr	= ({32{stage_if}} & pc) |
			  ({32{stage_exe & exe_bus_req}} & op_addr & ~32'b11);
	assign bus_wr	= stage_exe & exe_bus_wr;
	assign bus_out	= {32{stage_exe & exe_bus_req}} & exe_bus_out;
	assign bus_wr_mask = exe_bus_wr_mask;

`ifdef DUMP
	initial begin
		$dumpfile("dump.vcd");
		$dumpvars();
	end
`endif
endmodule;
