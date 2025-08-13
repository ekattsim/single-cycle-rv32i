library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity asyncBRAM_TB is
end entity asyncBRAM_TB;

architecture asyncBRAM_TB_ARCH of asyncBRAM_TB is

    -- constants
    constant ACTIVE : std_logic := '1';

    -- test types declaration
    type testRecord_t is record
        addrRam    : std_logic_vector(31 downto 0);
        dataInRam  : std_logic_vector(31 downto 0);
        writeEnRam : std_logic_vector(3 downto 0);

        rs1        : std_logic_vector(4 downto 0);
        rs2        : std_logic_vector(4 downto 0);
        rd         : std_logic_vector(4 downto 0);
        writeEnReg : std_logic;
    end record;
    type testArray_t is array(natural range <>) of testRecord_t;

    function generate_test_vectors return testArray_t is
        -- For convenience when specifying register addresses
        constant R0 : std_logic_vector(4 downto 0) := "00000";
        constant R5 : std_logic_vector(4 downto 0) := "00101";
        constant R6 : std_logic_vector(4 downto 0) := "00110";
        constant R7 : std_logic_vector(4 downto 0) := "00111";
        constant R8 : std_logic_vector(4 downto 0) := "01000";

        constant VECTORS : testArray_t := (
  									-- =====================================================================
  									-- Test 0: Initial State. Ensure all write enables are low.
        (
        addrRam    => x"00000000",
        dataInRam  => x"00000000",
        writeEnRam => "0000",
        rs1        => R0,
        rs2        => R0,
        rd         => R0,
        writeEnReg => '0'
        ),
  									-- =====================================================================
  									-- Test 1: Write a known value (0xAAAAAAAA) to BRAM address 0x100.
  									-- RegFile is not being written to.
        (
        addrRam    => x"00000100",
        dataInRam  => x"AAAAAAAA",
        writeEnRam => "1111",  		-- Enable all 4 bytes for a full word write
        rs1        => R0,
        rs2        => R0,
        rd         => R0,  			-- rd doesn't matter, but good to keep at 0
        writeEnReg => '0'
        ),
  									-- =====================================================================
  									-- Test 2: Write another known value (0x12345678) to BRAM address 0x104.
        (
        addrRam    => x"00000104",
        dataInRam  => x"12345678",
        writeEnRam => "1111",
        rs1        => R0,
        rs2        => R0,
        rd         => R0,
        writeEnReg => '0'
        ),
  									-- =====================================================================
  									-- Test 3: Read from BRAM addr 0x100 and write the result into RegFile register R5.
  									-- This tests the primary datapath: BRAM.dataOut -> RegFile.dataIn.
  									-- The testbench should later verify that R5 contains 0xAAAAAAAA.
        (
        addrRam    => x"00000100",  	-- Set RAM address to read from
        dataInRam  => x"00000000",  	-- dataIn doesn't matter for a read
        writeEnRam => "0000",  			-- BRAM write is disabled
        rs1        => R0,  				-- Not reading from RegFile yet
        rs2        => R0,
        rd         => R5,  				-- Destination register is R5
        writeEnReg => '1'  				-- Enable write to RegFile
        ),
  									-- =====================================================================
  									-- Test 4: Read from BRAM addr 0x104 and write the result into RegFile register R6.
  									-- This is a back-to-back BRAM read/RegFile write operation.
        (
        addrRam    => x"00000104",
        dataInRam  => x"00000000",
        writeEnRam => "0000",
        rs1        => R0,
        rs2        => R0,
        rd         => R6,  				-- Destination register is R6
        writeEnReg => '1'
        ),
  									-- =====================================================================
  									-- Test 5: Verify RegFile contents. Read from R5 and R6 simultaneously.
  									-- The testbench driver should check that RegFile.dataOut1 = 0xAAAAAAAA and RegFile.dataOut2 = 0x12345678.
        (
        addrRam    => x"00000000",  	-- BRAM op doesn't matter
        dataInRam  => x"00000000",
        writeEnRam => "0000",
        rs1        => R5,  				-- Read from R5
        rs2        => R6,  				-- Read from R6
        rd         => R0,
        writeEnReg => '0'  				-- Disable writes
        ),
  									-- =====================================================================
  									-- Test 6: Test BRAM byte-enable. Overwrite just one byte of the data at BRAM addr 0x100.
  									-- The value at 0x100 is 0xAAAAAAAA. We will write 0xDEADBEEF with a mask "0010",
  									-- which should only update the second byte (bits 15-8).
  									-- Expected result in BRAM: 0xAAAA BEEF AA -> 0xAABEEFAA
  									-- NOTE: Assumes writeEnRam(0) is for byte 0 (bits 7-0), (1) for byte 1 etc.
        (
        addrRam    => x"00000100",
        dataInRam  => x"DEADBEEF",
        writeEnRam => "0010",  			-- Enable only the second byte
        rs1        => R0,
        rs2        => R0,
        rd         => R0,
        writeEnReg => '0'
        ),
  									-- =====================================================================
  									-- Test 7: Read the modified value from BRAM addr 0x100 and write it to R7.
        (
        addrRam    => x"00000100",
        dataInRam  => x"00000000",
        writeEnRam => "0000",
        rs1        => R0,
        rs2        => R0,
        rd         => R7,  				-- Destination register is R7
        writeEnReg => '1'
        ),
  									-- =====================================================================
  									-- Test 8: Verify the byte-masked write. Read from R7.
  									-- The testbench should check that RegFile.dataOut1 is 0xAABEEFAA.
        (
        addrRam    => x"00000000",
        dataInRam  => x"00000000",
        writeEnRam => "0000",
        rs1        => R7,  				-- Read from R7
        rs2        => R0,
        rd         => R0,
        writeEnReg => '0'
        ),
  									-- =====================================================================
  									-- Test 9: Test writing to register R0 (zero register).
  									-- We read from BRAM (value is 0x12345678) and attempt to write it to R0. This should be ignored.
        (
        addrRam    => x"00000104",
        dataInRam  => x"00000000",
        writeEnRam => "0000",
        rs1        => R0,
        rs2        => R0,
        rd         => R0,  				-- Attempt to write to R0
        writeEnReg => '1'
        ),
  									-- =====================================================================
  									-- Test 10: Verify R0 is still zero.
  									-- The testbench should check that RegFile.dataOut1 is 0x00000000.
        (
        addrRam    => x"00000000",
        dataInRam  => x"00000000",
        writeEnRam => "0000",
        rs1        => R0,  				-- Read from R0
        rs2        => R0,
        rd         => R0,
        writeEnReg => '0'
        )
        );
    begin
        return VECTORS;
    end function generate_test_vectors;

    -- Instantiate the test vectors using the function
    constant TEST_VECTORS : testArray_t := generate_test_vectors;

    -- internal signals
    signal reset     : std_logic;
    signal coreClock : std_logic;
    signal bramClock : std_logic;

    signal addrRam    : std_logic_vector(31 downto 0);
    signal dataInRam  : std_logic_vector(31 downto 0);
    signal writeEnRam : std_logic_vector(3 downto 0);

    signal rs1        : std_logic_vector(4 downto 0);
    signal rs2        : std_logic_vector(4 downto 0);
    signal rd         : std_logic_vector(4 downto 0);
    signal dataOutRam : std_logic_vector(31 downto 0);
    signal writeEnReg : std_logic;

    signal rs1Data : std_logic_vector(31 downto 0);
    signal rs2Data : std_logic_vector(31 downto 0);

begin

    --============================================================================
    --  Reset
    --============================================================================
    SYSTEM_RESET : process
    begin
        reset <= ACTIVE;
        wait for 15 ns;
        reset <= not ACTIVE;
        wait;
    end process SYSTEM_RESET;

    --============================================================================
    --  Datapath timing constraint
    --============================================================================
    CORE_CLOCK : process
    begin
        coreClock <= ACTIVE;
        wait for 5 ns;
        coreClock <= not ACTIVE;
        wait for 5 ns;
    end process CORE_CLOCK;

    --============================================================================
    --  BRAM timing constraint is 5 times faster to make it feel async
    --============================================================================
    BRAM_CLOCK : process
    begin
        bramClock <= ACTIVE;
        wait for 1 ns;
        bramClock <= not ACTIVE;
        wait for 1 ns;
    end process BRAM_CLOCK;

    BRAM : entity work.blk_mem_gen_0
        port map (
            rsta  => reset,
            clka  => bramClock,
            ena   => '1',
            wea   => writeEnRam,
            addra => addrRam,
            dina  => dataInRam,
            douta => dataOutRam,

            rstb  => reset,
            clkb  => bramClock,
            enb   => '0',
            web   => (others => '0'),
            addrb => (others => '0'),
            dinb  => (others => '0')
        );

    REG_FILE : entity work.RegFile
        port map (
            reset     => reset,
            clock     => coreClock,
            rs1       => rs1,
            rs2       => rs2,
            rd        => rd,
            writeData => dataOutRam,
            writeEn   => writeEnReg,
            rs1Data   => rs1Data,
            rs2Data   => rs2Data
        );

    INPUT_DRIVER : process(reset, coreClock)
        variable index : natural;
    begin

        if (reset = ACTIVE) then
            addrRam    <= TEST_VECTORS(0).addrRam;
            dataInRam  <= TEST_VECTORS(0).dataInRam;
            writeEnRam <= TEST_VECTORS(0).writeEnRam;
            rs1        <= TEST_VECTORS(0).rs1;
            rs2        <= TEST_VECTORS(0).rs2;
            rd         <= TEST_VECTORS(0).rd;
            writeEnReg <= TEST_VECTORS(0).writeEnReg;
            index      := 0;
        elsif (rising_edge(coreClock)) then
            if (index < TEST_VECTORS'length) then
                addrRam    <= TEST_VECTORS(index).addrRam;
                dataInRam  <= TEST_VECTORS(index).dataInRam;
                writeEnRam <= TEST_VECTORS(index).writeEnRam;
                rs1        <= TEST_VECTORS(index).rs1;
                rs2        <= TEST_VECTORS(index).rs2;
                rd         <= TEST_VECTORS(index).rd;
                writeEnReg <= TEST_VECTORS(index).writeEnReg;

                index := index + 1;
            end if;
        end if;

    end process;
end asyncBRAM_TB_ARCH;
