library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ALU is
	generic (
		XLEN: integer
	);
	port (
		a, b: in unsigned(XLEN-1 downto 0);
		opcode: in std_logic_vector(1 downto 0);
		zero: out std_logic;
		result: out unsigned(XLEN-1 downto 0)
	);
end entity ALU;

architecture ALU_ARCH of ALU is
	signal result_s: unsigned(XLEN-1 downto 0);

begin

	result <= result_s;
	zero <= '1' when (result_s=0) else '0';

	OPERATOR_SELECT: process (a, b, opcode)
	begin
		case (opcode) is
			when "00" => result_s <= a and b;
			when "01" => result_s <= a or b;
			when "10" => result_s <= a + b;
			when "11" => result_s <= a - b;
			when others => result_s <= (others => '0');
		end case;
	end process;

end ALU_ARCH;
