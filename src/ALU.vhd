library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ALU is
	generic (
		XLEN: integer
	);
	port (
		operand1, operand2: in std_logic_vector(XLEN-1 downto 0);
		opcode: in std_logic_vector(1 downto 0);
		zero: out std_logic;
		result: out std_logic_vector(XLEN-1 downto 0)
	);
end entity ALU;

architecture ALU_ARCH of ALU is

	signal logicResult: std_logic_vector(XLEN-1 downto 0);
	signal arithResult: std_logic_vector(XLEN-1 downto 0);
	signal result_s: std_logic_vector(XLEN-1 downto 0);
	signal opcode0: std_logic;

begin

	opcode0 <= opcode(0);

	LOGIC_UNIT: process(operand1, operand2, opcode0)
	begin
		case (opcode0) is
			when '0' => logicResult <= operand1 and operand2;
			when others => logicResult <= operand1 or operand2;
		end case;
	end process;

	ARITH_UNIT: process(operand1, operand2, opcode0)
	begin
		case (opcode0) is
			when '0' => arithResult <= std_logic_vector(unsigned(operand1) + unsigned(operand2));
			when others => arithResult <= std_logic_vector(unsigned(operand1) - unsigned(operand2));
		end case;
	end process;

	ALU_CONTROL: with opcode(1) select
		result_s <= logicResult when '0',
					arithResult when others;

	ZERO_CHECK: zero <= '1' when (unsigned(result_s)=0) else '0';
	result <= result_s;

end ALU_ARCH;
