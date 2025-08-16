library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Core is
    port (
        reset : in std_logic;
        clock : in std_logic;

        currInstAddr : out std_logic_vector(31 downto 0);
        inst         : in  std_logic_vector(31 downto 0);

        memEn     : out std_logic;
        memWrite  : out std_logic_vector(3 downto 0);
        ALUResult : out std_logic_vector(31 downto 0);
        rs2Data   : out std_logic_vector(31 downto 0);
        data      : in  std_logic_vector(31 downto 0));
end entity Core;

architecture Core_ARCH of Core is

    -- general
    constant XLEN   : integer   := 32;
    constant ACTIVE : std_logic := '1';

    subtype word is std_logic_vector(XLEN-1 downto 0);

    -- fetch (IF)
    signal seqNextAddr  : word;
    signal nextInstAddr : word;

    -- decode (ID)
    type opcode_t is record
        r_type  : std_logic_vector(6 downto 0);
        i_type  : std_logic_vector(6 downto 0);
        s_type  : std_logic_vector(6 downto 0);
        sb_type : std_logic_vector(6 downto 0);
    end record;
    constant opcodes : opcode_t := (r_type => "0110011",
                                   i_type  => "0000011",
                                   s_type  => "0100011",
                                   sb_type => "1100111");

    signal opcode      : std_logic_vector(6 downto 0);
    signal functFields : std_logic_vector(9 downto 0);

    signal immediate : word;

    signal regWrite : std_logic;
    signal ALUOp    : std_logic_vector(1 downto 0);
    signal memRead  : std_logic;
    signal ALUSrc   : std_logic;
    signal memToReg : std_logic;
    signal branch   : std_logic;

    signal rs1       : word;
    signal rs2       : word;
    signal rd        : word;
    signal operand1  : word;
    signal operand2  : word;
    signal ALUOpCode : std_logic_vector(1 downto 0);

    -- execute (EX)
    signal zero        : std_logic;
    signal branchTaken : std_logic;
    signal branchAddr  : word;

    -- memory (MEM)

    -- writeback (WB)
    signal regWriteData : word;

begin

    NEXT_INST_MUX : with branchTaken select
        nextInstAddr <=
        branchAddr  when '1',
        seqNextAddr when others;

    PC_32 : entity work.PC
        generic map (
            XLEN => XLEN)
        port map (
            reset    => reset,
            clock    => clock,
            nextInst => nextInstAddr,
            currInst => currInstAddr);

	-- calculate next sequential instruction address
    seqNextAddr <= std_logic_vector(unsigned(currInstAddr) + to_unsigned(4, XLEN));

    RegFile_1 : entity work.RegFile
        port map (
            reset     => reset,
            clock     => clock,
            rs1       => inst(19 downto 15),
            rs2       => inst(24 downto 20),
            rd        => inst(11 downto 7),
            writeData => regWriteData,
            writeEn   => regWrite,
            rs1Data   => operand1,
            rs2Data   => rs2Data);

    -- purpose: extract and sign extend the immediate value from the instruction
    -- type   : combinational
    -- inputs : inst
    -- outputs: immediate
    IMM_GEN : process (inst) is
        variable opcode : std_logic_vector(6 downto 0);

    begin
        opcode := inst(6 downto 0);

        case opcode is
            when opcodes.i_type =>
                immediate <= std_logic_vector(resize(signed(inst(31 downto 20)), 32));

            when opcodes.s_type =>
                immediate <= std_logic_vector(resize(signed(inst(31 downto 25) & inst(11 downto 7)), 32));

            -- word aligned b/c there are no halfword instructions in rv32i
            when opcodes.sb_type =>
                immediate <= std_logic_vector(resize(signed(inst(31) & inst(7) & inst(30 downto 25) & inst(11 downto 9) & "00"), 32));

            when others => immediate <= (others => '-');
        end case;
    end process IMM_GEN;

	-- calculate branch instruction address
	branchAddr <= std_logic_vector(signed(currInstAddr) + signed(immediate));

    -- purpose: generate control signals for the datapath
    -- type   : combinational
    -- inputs : opcode
    -- outputs: regWrite, ALUOp, memWrite, memRead, ALUSrc, memToReg, branch
    CONTROL : process (opcode) is
    begin
        -- set defaults to avoid latches
        regWrite <= '0';
        ALUOp    <= (others => '0');  	-- "00" means add
        memWrite <= (others => '0');
        memRead  <= '0';
        ALUSrc   <= '0';
        memToReg <= '0';
        branch   <= '0';

        case opcode is
            when opcodes.r_type =>
                regWrite <= '1';
                ALUOp    <= "10";  		-- use functFields to determine ALUOp

            when opcodes.i_type =>
                regWrite <= '1';
                memRead  <= '1';
                ALUSrc   <= '1';
                memToReg <= '1';

            when opcodes.s_type =>
                memWrite <= (others => '1');
                ALUSrc   <= '1';

            when opcodes.sb_type =>
                ALUOp  <= "01";  		-- "01" means subtract
                branch <= '1';

            when others => null;
        end case;
    end process CONTROL;

    -- purpose: generates the ALU opcode
    -- type   : combinational
    -- inputs : functFields, ALUOp
    -- outputs: ALUOpCode
    ALU_CONTROL : process (functFields, ALUOp) is
    begin
        -- default value
        ALUOpCode <= (others => '0');

        case ALUOp is
            when "00" => ALUOpCode <= "10";
            when "01" => ALUOpCode <= "11";
            when others =>
                case functFields is
                    when "0000000000" => ALUOpCode <= "10";
                    when "0100000000" => ALUOpCode <= "11";
                    when "0000000111" => ALUOpCode <= "00";
                    when "0000000110" => ALUOpCode <= "01";
                    when others       => null;
                end case;
        end case;
    end process ALU_CONTROL;

    ALU_OP2_MUX : with ALUSrc select
        operand2 <=
        immediate when '1',
        rs2Data   when others;

	ALU_1: entity work.ALU
        generic map (
            XLEN => XLEN)
        port map (
            operand1 => operand1,
            operand2 => operand2,
            opcode   => ALUOpCode,
            zero     => zero,
            result   => ALUResult);

	-- misc dataflow statements
	memEn <= or memWrite or memRead;
	branchTaken <= zero and branch;

    ALU_MEM_MUX : with memToReg select
        regWriteData <=
        data      when '1',
        ALUResult when others;

end Core_ARCH;
