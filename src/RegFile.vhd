library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RegFile is
	port (
		reset, clock: std_logic;
		rs1: in unsigned(4 downto 0);
		rs2: in unsigned(4 downto 0);
		rd: in unsigned(4 downto 0);
		writeData: in unsigned(31 downto 0);
		writeEn: in std_logic;

		rs1Data: out unsigned(31 downto 0);
		rs2Data: out unsigned(31 downto 0)
	);
end entity RegFile;

architecture RegFile_ARCH of RegFile is
	constant ACTIVE: std_logic := '1';
	type reg is array (0 to 31) of unsigned(31 downto 0);
begin

	RegisterFile: process (reset, clock, rs1, rs2)
		variable x: reg;
	begin

		if (reset=ACTIVE) then
			for i in 1 to 31 loop
				x(i) := (others => '0');
			end loop;
		elsif (rising_edge(clock)) then
			if (writeEn=ACTIVE) then
				x(to_integer(rd)) := writeData;
			end if;
		end if;

		-- x0 hardwired to 0
		x(0) := (others => '0');

		rs1Data <= x(to_integer(rs1));
		rs2Data <= x(to_integer(rs2));

	end process;

end RegFile_ARCH;
