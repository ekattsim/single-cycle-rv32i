library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity PC is
    generic (
        XLEN : integer
    );
    port (
        reset, clock : in  std_logic;
        nextInst     : in  std_logic_vector(XLEN-1 downto 0);
        currInst     : out std_logic_vector(XLEN-1 downto 0)
    );
end entity PC;

architecture PC_ARCH of PC is

    constant ACTIVE       : std_logic                         := '1';
    constant BASE_ADDRESS : std_logic_vector(XLEN-1 downto 0) := (others => '0');

begin

    PC_REGISTER : process(reset, clock)
    begin
        if (reset = ACTIVE) then
            currInst <= BASE_ADDRESS;
        elsif (rising_edge(clock)) then
            currInst <= nextInst;
        end if;
    end process;

end PC_ARCH;
