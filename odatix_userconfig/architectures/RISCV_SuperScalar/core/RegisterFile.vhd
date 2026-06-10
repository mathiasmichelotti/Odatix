-------------------------------------------------------------------------
-- Design unit: Register file
-- Description: 32 general purpose registers
--     - 4 read ports
--     - 2 write port
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity RegisterFile is
    port ( 
        clock            : in  std_logic;
        reset            : in  std_logic; 
        write_a          : in  std_logic;
        write_b          : in  std_logic;
        rs1_a            : in  std_logic_vector(4 downto 0);
        rs2_a            : in  std_logic_vector(4 downto 0);
        rs1_b            : in  std_logic_vector(4 downto 0);
        rs2_b            : in  std_logic_vector(4 downto 0);
        writeRegister_a  : in  std_logic_vector(4 downto 0);
        writeRegister_b  : in  std_logic_vector(4 downto 0);
        writeData_a      : in  std_logic_vector(31 downto 0);
        writeData_b      : in  std_logic_vector(31 downto 0);
        readData1_a      : out std_logic_vector(31 downto 0); 
        readData2_a      : out std_logic_vector(31 downto 0);
        readData1_b      : out std_logic_vector(31 downto 0); 
        readData2_b      : out std_logic_vector(31 downto 0)  
    );
end RegisterFile;

architecture structural of RegisterFile is

    type RegArray is array(0 to 31) of std_logic_vector(31 downto 0);
    signal reg : RegArray;            -- Array with the stored registers value                            
    signal writeEnable : std_logic_vector(31 downto 0); -- Registers write enable signal
    type init_values is array(0 to 31) of integer;
    constant INIT_VALUE : init_values := (2 => 16384, others => 0); -- reg(2) = stack pointer
    signal writeData : regArray;

begin         

    Registers: for i in 0 to 31 generate        

        -- Register $0 is the constant 0, not a register.
        -- This is implemented by never enabling writes to register $0.
        writeEnable(i) <= '1' when i > 0 and ((UNSIGNED(writeRegister_a) = i and write_a = '1') or (UNSIGNED(writeRegister_b) = i and write_b = '1')) else '0';
        
        writeData(i) <= writeData_a when (UNSIGNED(writeRegister_a) = i and write_a = '1') else writeData_b;

        -- Generate the remaining registers
        Regs: entity work.RegisterNbits 
            generic map (
                LENGTH      => 32,
                INIT_VALUE  => INIT_VALUE(i)
            )
            port map (
                clock   => clock, 
                reset   => reset, 
                ce      => writeEnable(i), 
                d       => writeData(i), 
                q       => reg(i)
            );
    end generate Registers; 
    
    -- Register source 1 instruction a (rs1_a)
    ReadData1_a <= reg(TO_INTEGER(UNSIGNED(rs1_a)));   

    -- Register source 2 instruction a (rs2_a)
    ReadData2_a <= reg(TO_INTEGER(UNSIGNED(rs2_a)));

    -- Register source 1 instruction b (rs1_b)
    ReadData1_b <= reg(TO_INTEGER(UNSIGNED(rs1_b)));   

    -- Register source 2 instruction b (rs2_b)
    ReadData2_b <= reg(TO_INTEGER(UNSIGNED(rs2_b)));
   
end structural;