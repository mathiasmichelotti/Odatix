-------------------------------------------------------------------------
-- Design unit: ALU
-- Description: 
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.RISCV_package.all;

entity ALU is
    port( 
        operand1          : in  std_logic_vector(31 downto 0);
        operand2          : in  std_logic_vector(31 downto 0);
        pc                : in  std_logic_vector(31 downto 0);
        branch_prediction : in  std_logic;
        result            : out std_logic_vector(31 downto 0);
        branch_decision   : out std_logic;
        bubble_branch     : out std_logic;
        operation         : in Instruction_type 
    );
end ALU;

architecture behavioral of ALU is

    signal op1_u, op2_u: UNSIGNED(31 downto 0);
    signal op1_s, op2_s: SIGNED(31 downto 0);
    signal result_shift : STD_LOGIC_VECTOR(31 downto 0);

    constant zero : STD_LOGIC_VECTOR(31 downto 0):= (others=>'0'); 
    constant one  : STD_LOGIC_VECTOR(31 downto 0):= x"00000001";
    constant four : UNSIGNED(31 downto 0)        := x"00000004"; 

    signal branch_decision_sig : std_logic;

begin

    op1_u <= UNSIGNED(operand1);
    op2_u <= UNSIGNED(operand2);

    op1_s <= SIGNED(operand1);
    op2_s <= SIGNED(operand2); 

    result <= operand2                                                       when operation = LUI else 
              std_logic_vector(unsigned(pc) + op2_u)                         when operation = AUIPC else
              std_logic_vector(unsigned(pc) + four)                          when operation = JAL or operation = JALR else
              operand1 and operand2                                          when operation = ANDI or operation = ANDD else
              one                                                            when ((operation = SLTI or operation = SLT) and (op1_s < op2_s)) or ((operation = SLTIU or operation = SLTU) and (op1_u < op2_u)) else
              zero                                                           when ((operation = SLTI or operation = SLT) and (op1_s >= op2_s)) or ((operation = SLTIU or operation = SLTU) and (op1_u >= op2_u)) else
              operand1 xor operand2                                          when operation = XORI or operation = XORR else
              operand1 or operand2                                           when operation = ORR or operation = ORI else
              result_shift                                                   when operation = SLLI or operation = SLLL or operation = SRLI or operation = SRLL or operation = SRAI or operation = SRAA else
              std_logic_vector(op1_s - op2_s)                                when operation = SUB else 
              std_logic_vector(op1_s + op2_s); --B types, Load, Store, ADDI, ADD, and others instructions;

    i_shift_unit:    entity work.shift_unit
        port map (
            operand1       => operand1,
            operand2       => operand2,
            result         => result_shift, 
            operation      => operation
    );

    -- BRANCH DETECTION --

    branch_decision_sig <= '1' when operation = JAL  or 
                                   (operation = BEQ  and operand1 = operand2) or
                                   (operation = BNE  and operand1 /= operand2) or
                                   (operation = BLT  and signed(operand1) < signed(operand2)) or
                                   (operation = BGE  and signed(operand1) >= signed(operand2)) or
                                   (operation = BLTU and operand1 < operand2) or
                                   (operation = BGEU and operand1 >= operand2) else
                       '0';
    
    bubble_branch <= '1' when branch_decision_sig /= branch_prediction else
                     '0';
                        
    branch_decision <= branch_decision_sig;
              
end behavioral;

