library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Core_tb is
end entity Core_tb;

architecture Core_tb_arch of Core_tb is

    -- general
    subtype word is std_logic_vector(31 downto 0);

    -- Memory contents
    type ramReg_t is record
        addr : word;
        data : word;
    end record;
    type ram_t is array(17 downto 0) of ramReg_t;

    constant memContents : ram_t :=
        (
        (addr => X"00000000", data => X"19002503"),
        (addr => X"00000004", data => X"19402583"),
        (addr => X"00000008", data => X"00b57633"),
        (addr => X"0000000C", data => X"18c02c23"),
        (addr => X"00000010", data => X"00b566b3"),
        (addr => X"00000014", data => X"18D02E23"),
        (addr => X"00000018", data => X"00b50733"),
        (addr => X"0000001C", data => X"1ae02023"),
        (addr => X"00000020", data => X"40b507b3"),
        (addr => X"00000024", data => X"1af02223"),
        (addr => X"00000028", data => X"FEB506E7"),
        (addr => X"0000002C", data => X"18002c23"),
        (addr => X"00000030", data => X"18002e23"),
        (addr => X"00000034", data => X"1a002023"),
        (addr => X"00000038", data => X"1a002223"),
        (addr => X"0000003C", data => X"00000067"),
        (addr => X"00000190", data => X"00000000"),
        (addr => X"00000194", data => X"00000000")
        );

    -- component ports
    signal reset         : std_logic;
    signal clock         : std_logic;
    signal core_instAddr : word;
    signal inst          : word;
    signal memEn         : std_logic;
    signal memWrite      : std_logic_vector(3 downto 0);
    signal ALUResult     : word;
    signal rs2Data       : word;
    signal data          : word;

    -- Testbench control signals for BRAM Port A
    signal tb_mem_grant : std_logic;
    signal tb_addr      : word;
    signal tb_wea       : std_logic_vector(3 downto 0);
    signal tb_dina      : word;

    -- Signals connecting directly to BRAM Port A (driven by the mux)
    signal bram_addra : word;
    signal bram_wea   : std_logic_vector(3 downto 0);
    signal bram_dina  : word;
    signal bram_douta : word;

    -- Clock signals
    signal coreClockEn : std_logic := '0';
    signal bramClk     : std_logic;

begin

    -- Multiplexer for BRAM Port A
    -- This process prevents multiple drivers on the BRAM's address/write ports
    BRAM_PORTA_MUX : process(all)
    begin
        if tb_mem_grant = '1' then
            -- Testbench has control for loading/checking memory
            bram_addra <= tb_addr;
            bram_wea   <= tb_wea;
            bram_dina  <= tb_dina;
        else
            -- Core has control for instruction fetching
            bram_addra <= core_instAddr;
            bram_wea   <= "0000";  -- Core only reads from instruction port
            bram_dina  <= (others => '0');
            if coreClockEn = '1' then
                inst <= bram_douta;
            else
                inst <= (others => '0');
            end if;
        end if;
    end process;

    BRAM : entity work.blk_mem_gen_0
        port map (
            -- instruction memory port
            rsta  => reset,
            clka  => bramClk,
            ena   => '1',
            wea   => bram_wea,
            addra => bram_addra,
            dina  => bram_dina,
            douta => bram_douta,

            -- data memory port
            rstb  => reset,
            clkb  => bramClk,
            enb   => memEn,
            web   => memWrite,
            addrb => ALUResult,
            dinb  => rs2Data,
            doutb => data);

    BRAM_CLOCK : process
    begin
        bramClk <= '1';
        wait for 1 ns;
        bramClk <= '0';
        wait for 1 ns;
    end process;

    CORE_CLOCK : process
    begin
		if coreClockEn = '1' then
			clock <= '1';
			wait for 5 ns;
			clock <= '0';
			wait for 5 ns;
		else
			clock <= '0';
			wait for 10 ns;
		end if;
    end process;

    -- component instantiation
    UUT : entity work.Core
        port map (
            reset        => reset,
            clock        => clock,
            currInstAddr => core_instAddr,
            inst         => inst,
            memEn        => memEn,
            memWrite     => memWrite,
            ALUResult    => ALUResult,
            rs2Data      => rs2Data,
            data         => data);

    -- Main stimulus, test, and assertion process
    STIMULUS_AND_CHECK : process
        -- Helper procedures now drive the dedicated 'tb_' signals
        procedure write_mem(addr : in word; data_in : in word) is
        begin
            tb_wea  <= "1111";
            tb_addr <= addr;
            tb_dina <= data_in;
            wait for 2 ns;
        end procedure;

        procedure read_mem(addr : in word; data_out : out word) is
        begin
            tb_wea   <= "0000";
            tb_addr  <= addr;
            wait for 4 ns;
            data_out := bram_douta;
        end procedure;

        procedure initialize_system is
        begin
            report "Initializing system: Granting memory access to Testbench.";
            tb_mem_grant <= '1';  		-- Take control of the BRAM
            report "Resetting Core and BRAM...";
            reset        <= '1';
            coreClockEn  <= '0';
            wait for 15 ns;
            reset        <= '0';
            wait for 5 ns;

            report "Loading program into instruction memory...";
            for i in memContents'range loop
                write_mem(memContents(i).addr, memContents(i).data);
            end loop;
            report "Program loading complete.";
        end procedure;

        variable read_data : word;
        constant VAL1_NE   : word := X"AAAAAAAA";
        constant VAL2_NE   : word := X"55555555";
        constant VAL_EQ    : word := X"12345678";
        constant ADDR_VAL1 : word := std_logic_vector(to_unsigned(400, 32));
        constant ADDR_VAL2 : word := std_logic_vector(to_unsigned(404, 32));
        constant ADDR_AND  : word := std_logic_vector(to_unsigned(408, 32));
        constant ADDR_OR   : word := std_logic_vector(to_unsigned(412, 32));
        constant ADDR_ADD  : word := std_logic_vector(to_unsigned(416, 32));
        constant ADDR_SUB  : word := std_logic_vector(to_unsigned(420, 32));

    begin
        report "Starting Testbench Simulation...";

        -- TEST CASE 1: x10 != x11
        report "--- Starting Test Case 1: x10 != x11 ---";
        initialize_system;
        write_mem(ADDR_VAL1, VAL1_NE);
        write_mem(ADDR_VAL2, VAL2_NE);

        report "Releasing memory control to Core and enabling clock.";
        tb_mem_grant <= '0';  			-- Give control to the Core
        wait for 5 ns;
        coreClockEn  <= '1';
        wait for 200 ns;
        coreClockEn  <= '0';
        tb_mem_grant <= '1';  			-- Take back control to check memory
        report "Core execution finished. Verifying results for Case 1.";

        read_mem(ADDR_AND, read_data);
        assert read_data = X"00000000" report "TESTCASE 1 FAILED: AND result should be zero!" severity error;
        read_mem(ADDR_OR, read_data);
        assert read_data = X"00000000" report "TESTCASE 1 FAILED: OR result should be zero!" severity error;
        read_mem(ADDR_ADD, read_data);
        assert read_data = X"00000000" report "TESTCASE 1 FAILED: ADD result should be zero!" severity error;
        read_mem(ADDR_SUB, read_data);
        assert read_data = X"00000000" report "TESTCASE 1 FAILED: SUB result should be zero!" severity error;
        report "--- Test Case 1 Passed ---";
        wait for 20 ns;

        -- TEST CASE 2: x10 == x11
        report "--- Starting Test Case 2: x10 == x11 ---";
        initialize_system;
        write_mem(ADDR_VAL1, VAL_EQ);
        write_mem(ADDR_VAL2, VAL_EQ);

        report "Releasing memory control to Core and enabling clock.";
        tb_mem_grant <= '0';  			-- Give control to the Core
        wait for 5 ns;
        coreClockEn  <= '1';
        wait for 200 ns;
        coreClockEn  <= '0';
        tb_mem_grant <= '1';  			-- Take back control to check memory
        report "Core execution finished. Verifying results for Case 2.";

        read_mem(ADDR_AND, read_data);
        assert read_data = (VAL_EQ and VAL_EQ) report "TESTCASE 2 FAILED: AND result mismatch!" severity error;
        read_mem(ADDR_OR, read_data);
        assert read_data = (VAL_EQ or VAL_EQ) report "TESTCASE 2 FAILED: OR result mismatch!" severity error;
        read_mem(ADDR_ADD, read_data);
        assert read_data = std_logic_vector(unsigned(VAL_EQ) + unsigned(VAL_EQ)) report "TESTCASE 2 FAILED: ADD result mismatch!" severity error;
        read_mem(ADDR_SUB, read_data);
        assert read_data = std_logic_vector(unsigned(VAL_EQ) - unsigned(VAL_EQ)) report "TESTCASE 2 FAILED: SUB result mismatch!" severity error;
        report "--- Test Case 2 Passed ---";

        report "All test cases passed. Simulation finished successfully." severity failure;
        wait;
    end process;

end architecture Core_tb_arch;
