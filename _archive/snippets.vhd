-- snippets.vhd
-- Author: DigitalDesignDen (Patrick Goncalves)
-- Date: June 6, 2024
-- Description:
-- This file contains snippets of code for a 3D graphics pipeline rendering to HDMI output
-- that have been used often during development of different approached to the problem.
-- These snippets include a pipelined matrix
-- multiplication and perspective division process, as well as a non-pipelined version.






signal vertex_index : integer range 0 to s_modelVertices'length-1 := 0;
signal stage : integer range 0 to 3 := 0;

signal x_mult, y_mult, w_mult : integer_vector(0 to 3);
signal x_sum, y_sum, w_sum : integer;

signal x_final, y_final : integer;

begin
	process(clock_25)
	variable ranThisFrame : boolean := false;
	begin
		if rising_edge(clock_25) then

            if to_integer(unsigned(hc)) = 640 and to_integer(unsigned(vc)) = 480 then
                ranThisFrame := false;
            end if;

			if not ranThisFrame then
				case stage is
					when MULT =>
						-- Load multiplications into pipeline registers
						x_mult(0) <= s_A(0,0) * s_modelVertices(vertex_index)(0);
						x_mult(1) <= s_A(0,1) * s_modelVertices(vertex_index)(1);
						x_mult(2) <= s_A(0,2) * s_modelVertices(vertex_index)(2);
						x_mult(3) <= s_A(0,3) * s_modelVertices(vertex_index)(3);
						
						y_mult(0) <= s_A(1,0) * s_modelVertices(vertex_index)(0);
						y_mult(1) <= s_A(1,1) * s_modelVertices(vertex_index)(1);
						y_mult(2) <= s_A(1,2) * s_modelVertices(vertex_index)(2);
						y_mult(3) <= s_A(1,3) * s_modelVertices(vertex_index)(3);
		
						w_mult(0) <= s_A(3,0) * s_modelVertices(vertex_index)(0);
						w_mult(1) <= s_A(3,1) * s_modelVertices(vertex_index)(1);
						w_mult(2) <= s_A(3,2) * s_modelVertices(vertex_index)(2);
						w_mult(3) <= s_A(3,3) * s_modelVertices(vertex_index)(3);
		
						stage <= ADD; -- Move to addition stage
		
					when ADD =>
						-- Compute sum of multiplication results
						x_sum <= x_mult(0) + x_mult(1) + x_mult(2) + x_mult(3);
						y_sum <= y_mult(0) + y_mult(1) + y_mult(2) + y_mult(3);
						w_sum <= w_mult(0) + w_mult(1) + w_mult(2) + w_mult(3);
		
						stage <= PERSDIV; -- Move to perspective division
		
					when PERSDIV =>
						-- Apply perspective division
						if w_sum /= 0 then
							x_final <= ((x_sum * 200) / w_sum) + 300;
							y_final <= ((y_sum * 200) / w_sum) + 280;
						else
							x_final <= x_sum + 300;
							y_final <= y_sum + 280;
						end if;
						
						stage <= REG; -- Move to writing output
	
					when REG => 
						x_reg <= x_final;
						y_reg <= y_final;
						stage <= FINAL;
		
					when FINAL =>
						-- Store final results and move to next vertex
						s_P2(vertex_index)(0) <= x_reg;
						s_P2(vertex_index)(1) <= y_reg;
						
						if vertex_index = s_modelVertices'length-1 then
							vertex_index <= 0; -- Reset after last vertex
							ranThisFrame := true;
						else
							vertex_index <= vertex_index + 1;
						end if;
						
						stage <= MULT; -- Restart pipeline for next vertex
	
					when others => 
						stage <= MULT;
						
				end case;
			end if;
		end if;
	end process;



process(clock_25)
-- Use variables to store intermediate results
variable x_trans, y_trans, w_trans : integer;
begin
	if rising_edge(clock_25) then
		for k in 0 to s_modelVertices'length-1 loop
			-- Perform matrix multiplication for transformation
			x_trans := (s_A(0,0) * s_modelVertices(k)(0)) + 
					   (s_A(0,1) * s_modelVertices(k)(1)) + 
					   (s_A(0,2) * s_modelVertices(k)(2)) + 
					   (s_A(0,3) * s_modelVertices(k)(3));

			y_trans := (s_A(1,0) * s_modelVertices(k)(0)) + 
					   (s_A(1,1) * s_modelVertices(k)(1)) + 
					   (s_A(1,2) * s_modelVertices(k)(2)) + 
					   (s_A(1,3) * s_modelVertices(k)(3));

			w_trans := (s_A(3,0) * s_modelVertices(k)(0)) + 
					   (s_A(3,1) * s_modelVertices(k)(1)) + 
					   (s_A(3,2) * s_modelVertices(k)(2)) + 
					   (s_A(3,3) * s_modelVertices(k)(3));

			-- Apply perspective division only if w /=Â  0
			if w_trans /= 0 then
				s_P2(k)(0) <= ((x_trans * 200) / w_trans) + 300; -- Scale before division
				s_P2(k)(1) <= ((y_trans * 200) / w_trans) + 280;
			else
				s_P2(k)(0) <= x_trans;
				s_P2(k)(1) <= y_trans; 
			end if;
		end loop;
	end if;
end process;