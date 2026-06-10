-------------------------------------------------------------------------
-- Design unit: Memory 2 ports
-- Description: Parametrizable 32 bits word memory
-------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all; 
use std.textio.all;
use work.Util_package.all;


entity Memory_2_ports is
    generic (
        SIZE            : integer := 32;       -- Memory depth
        DATA_WIDTH      : integer := 32;
        START_ADDRESS   : std_logic_vector(31 downto 0) := (others=>'0');    -- Address to be mapped to address 0x00000000
        imageFileName   : string := "UNUSED"   -- Memory content to be loaded
    );
    port (  
        clock           : in std_logic;
        MemWrite_0      : in std_logic_vector(3 downto 0);
        MemWrite_1      : in std_logic_vector(3 downto 0);
        address_0       : in std_logic_vector(31 downto 0);
        address_1       : in std_logic_vector(31 downto 0);
        data_i_0        : in std_logic_vector(31 downto 0);
        data_i_1        : in std_logic_vector(31 downto 0);
        data_o_0        : out std_logic_vector(31 downto 0);
        data_o_1        : out std_logic_vector(31 downto 0)
    );
end Memory_2_ports;


architecture behavioral of Memory_2_ports is

    -- Word addressed memory
    type Memory is array (0 to SIZE) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal memoryArray: Memory;
        
    
    ----------------------------------------------------------------------------
    -- This procedure loads the memory array with the specified file in 
    -- the following format
    --
    --
    --      Address    Code        Basic                  Source
    --
    --    0x00400000  0x014b4820  add $9,$10,$11    4  add $t1, $t2, $t3
    --    0x00400004  0x016a4822  sub $9,$11,$10    5  sub $t1, $t3, $t2    
    --    0x00400008  0x014b4824  and $9,$10,$11    6  and $t1, $t2, $t3
    --    0x0040000c  0x014b4825  or $9,$10,$11     7  or  $t1, $t2, $t3
    --    ...
    ----------------------------------------------------------------------------


    function MemoryLoad(imageFileName: in string) return Memory is
        
        file imageFile : TEXT open READ_MODE is imageFileName;
        variable memoryArray: Memory;
        variable fileLine    : line;                -- Stores a read line from a text file
        variable str         : string(1 to 8);      -- Stores an 8 characters string
        variable char        : character;           -- Stores a single character
        variable bool        : boolean;             
        variable address     : std_logic_vector(31 downto 0);
        variable data        : std_logic_vector(DATA_WIDTH-1 downto 0);
                
        begin
        
            while NOT (endfile(imageFile)) loop    -- Main loop to read the file
                
                -- Read a file line into 'fileLine'
                readline(imageFile, fileLine);    
                
                -- Verifies if the line contains address and code.
                -- Such lines start with "0x"
                if fileLine'length > 2 and fileLine(1 to 2) = "0x" then
                
                    -- Read '0' and 'x'
                    read(fileLine, char, bool);
                    read(fileLine, char, bool);
                    
                    -- Read the address character by character and stores in 'str'
                    for i in 1 to 8 loop
                        read(fileLine, char, bool);
                        str(i) := char;
                    end loop;
                    
                    
                    -- Converts the string address 'str' to std_logic_vector
                    address := StringToStdLogicVector(str);
                    
                    -- Sets the real address
                    address := STD_LOGIC_VECTOR(UNSIGNED(address) - UNSIGNED(START_ADDRESS));
                    
                                    
                    -- Read the 2 blanks between address and code
                    read(fileLine, char, bool);
                    read(fileLine, char, bool);
                    
                    
                    -- Read '0' and 'x'
                    read(fileLine, char, bool);
                    read(fileLine, char, bool);
                    
                    -- Read the code/data character by character and stores in 'str'
                    for i in 1 to 8 loop
                        read(fileLine, char, bool);
                        str(i) := char;
                    end loop;
                    
                    -- Converts the string code/data 'str' to std_logic_vector
                    data := StringToStdLogicVector(str);
                    
                    -- Converts the byte address to word address
                    address := "00" & address(31 downto 2);
                    
                    -- Stores the 'data' into the memoryArray
                    memoryArray(TO_INTEGER(UNSIGNED(address))) := data;
                    
                end if;
            end loop;
            
            return memoryArray;
            
    end MemoryLoad;
    
    signal wordAddress_0, wordAddress_1, mappedAddress_0, mappedAddress_1: std_logic_vector(31 downto 0);

begin
        
    mappedAddress_0 <= STD_LOGIC_VECTOR(UNSIGNED(address_0) - UNSIGNED(START_ADDRESS));
    mappedAddress_1 <= STD_LOGIC_VECTOR(UNSIGNED(address_1) - UNSIGNED(START_ADDRESS));
    
    -- Converts byte address in word address
    --wordAddress <= "00" & address(31 downto 2);
    wordAddress_0 <= "00" & mappedAddress_0(31 downto 2);
    wordAddress_1 <= "00" & mappedAddress_1(31 downto 2);
        
    -- Memory read
    data_o_0 <= memoryArray(TO_INTEGER(UNSIGNED(wordAddress_0))) when UNSIGNED(wordAddress_0) < SIZE else (others=>'U');
    data_o_1 <= memoryArray(TO_INTEGER(UNSIGNED(wordAddress_1))) when UNSIGNED(wordAddress_1) < SIZE else (others=>'U');

    -- Process to load the memory array and control the memory writing
    process(clock)
        variable memoryLoaded: boolean := false;    -- Indicates if the memory was already loaded
    begin        
        if not memoryLoaded then
            if imageFileName /= "UNUSED" then                
                memoryArray <= MemoryLoad(imageFileName);
            end if;
             
             memoryLoaded := true;
        end if;
        
        if rising_edge(clock) then    -- Memory writing        
            if MemWrite_0(0) = '1' and MemWrite_1(0) = '1' then
                if UNSIGNED(wordAddress_0) < SIZE and UNSIGNED(wordAddress_1) < SIZE then
                    memoryArray(TO_INTEGER(UNSIGNED(wordAddress_0))) <= data_i_0;
                    memoryArray(TO_INTEGER(UNSIGNED(wordAddress_1))) <= data_i_1;

                else
                    report "******************* MEMORY WRITE (0 OR 1) OUT OF BOUNDS *************"
                    severity error;
                end if;
            elsif MemWrite_0(0) = '1' and MemWrite_1(0) = '0' then
                if UNSIGNED(wordAddress_0) < SIZE then
                    memoryArray(TO_INTEGER(UNSIGNED(wordAddress_0))) <= data_i_0;

                else
                    report "******************* MEMORY WRITE 0 OUT OF BOUNDS *************"
                    severity error;
                end if;
            elsif MemWrite_0(0) = '0' and MemWrite_1(0) = '1' then
                if UNSIGNED(wordAddress_1) < SIZE then
                    memoryArray(TO_INTEGER(UNSIGNED(wordAddress_1))) <= data_i_1;

                else
                    report "******************* MEMORY WRITE 1 OUT OF BOUNDS *************"
                    severity error;
                end if;
            end if;
        end if;
        
    end process;
        
end behavioral;