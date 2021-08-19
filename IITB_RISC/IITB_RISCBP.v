/*
Six stage RISC Pipelined Processor designed for Project 1 of EE739 Processor Design at IIT Bombay
Problem Statement was given by Prof. Virendra Singh
It has 8 registers of 16 bits each.
The Design has 15 instructions.
The impementation also has a Branch history table which uses 1 history bit to store branch history.
*/

module IITB_RISCBP (clk1, rst);

	input clk1,rst;
	
	//Stages should be Fetch, Decode, Register Read, Execute, Memory, Write Back.
	
	reg [15:0] PC, IF_ID_IR, IF_ID_NPC,NPC;								//Fetch to decode stage registers
	reg [15:0] ID_RR_IR, ID_RR_NPC; 								//ID to RR Instruction Reg and NPC
	reg [15:0] RR_EX_A, RR_EX_B,RR_EX_IR,RR_EX_NPC,WB_IR; 		//RR to EX register and imm values
	reg [8:0] RR_EX_Imm,Ex_MEM_Imm;
	reg [3:0] ID_RR_type, RR_EX_type, EX_MEM_type, MEM_WB_type,WB_type;
	reg [15:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B,EX_MEM_NPC;
	reg EX_MEM_cond;
	reg [15:0] MEM_WB_IR, MEM_WB_ALUOut, MEM_WB_LMD,WB_ALUOut,WB_LMD;
	
	reg ID_RR_H,RR_EX_H,EX_MEM_H;
	
	reg [15:0] Reg [0:7]; // Register bank (8 x 16)
	reg [15:0] iMem [0:1023]; // 1024 x 16 instruction memory
	reg [15:0] dMem [0:1023]; // 1024 x 16 data memory
	reg [16:0] BHT [15:0]; //16th bit history, LSB 16 bits are PC address.
	reg itsthatcase;
	
	reg [2:0] ID_RR_RA,ID_RR_RB,ID_RR_RC,RR_EX_RA,RR_EX_RB,RR_EX_RC,EX_MEM_RA,EX_MEM_RB,EX_MEM_RC,MEM_WB_RA,MEM_WB_RB,MEM_WB_RC,WB_RC,WB_RA,WB_RB;
	
	//Flags
	reg EX_MEM_zero,MEM_WB_zero,zero;
	reg EX_MEM_carry,MEM_WB_carry,WB_carry,WB_zero,carry; 
	reg [3:0] MRU,INDEX,pos;
	reg found;
	parameter 	RR_ALU=4'b0000, RI_ALU_A=4'b0001, RI_ALU_L=4'b0010, RI_L=4'b0011,RI_S=4'b0100, LM_T=4'b0101,
				SM_T=4'b0110, BRANCH=4'b0111, JUMP=4'b1000;					//Instruction types
				
	parameter 	ADD=4'b0000, ADI=4'b0001, NDU=4'b0010, LHI=4'b0011, LW=4'b0100, SW=4'b0101, LM=4'b0110,	//Opcades
				SM=4'b0111, BEQ=4'b1100, JAL=4'b1000, JLR=4'b1001, HLT=4'b1010, NOP=4'b1111;    
	
	parameter HALT=16'b1010_000000000000;
	
	reg HALTED;
	
	reg ID_RR_TAKEN_BRANCH,RR_EX_TAKEN_BRANCH,EX_MEM_TAKEN_BRANCH,MEM_WB_TAKEN_BRANCH,IF_ID_TAKEN_BRANCH,WB_TAKEN_BRANCH;
	integer i;
	initial
	begin
		for(i=0;i<16;i=i+1) //initialize the BHT with all taken branches
		begin
			BHT[i][0]={16'd0,1'b1};
		end
		MRU=0;
		INDEX=0;
		found=0;
		Reg[0]=16'h0000;
		Reg[1]=16'h0001;
		Reg[2]=16'h0002;
		Reg[3]=16'h0003;
		Reg[4]=16'h0004;
		Reg[5]=16'h0005;
		Reg[6]=16'h0006;
		Reg[7]=16'h0007;
		
		PC=16'hffff;
		NPC=16'h0000;
		
		dMem[0]=16'b0000_0000_0000_0000;
		dMem[1]=16'b0000_0000_0000_0001;		 
		dMem[2]=16'b0000_0000_0000_0010;
		dMem[3]=16'b0000_0000_0000_0011;
		dMem[4]=16'b0000_0000_0000_0100;
		dMem[5]=16'b0000_0000_0000_0101;
		dMem[6]=16'b0000_0000_0000_0110;
		dMem[7]=16'b0000_0000_0000_0111;
		dMem[8]=16'b0000_0000_0000_1000;
		dMem[9]=16'b0000_0000_0000_1001;
		
		//iMem[0]=16'b0000_000_001_010_000;  	//ADD R0+R1 store in R2							//Works
		//iMem[1]=16'b0000_000_001_011_010;		//ADC R1+R0 store in R3 if carry flag is set	//works
		//iMem[2]=16'b0000_000_001_011_001;		//ADZ R0+R1 store in R2	if zero flag is set		//works
		//iMem[3]=16'b0001_000_010_000111;		//Add 7 to contents of R0 and store in reg 2	//Works
		//iMem[3]=16'b0010_000_001_011_000;		//NAND R1+R0 store in R2 						//Works
		//iMem[1]=16'b0010_000_001_011_010;		//NAND R1+R0 store in R3 if carry flag is set 	//Works
		//iMem[1]=16'b0010_000_001_011_001;		//NAND R1+R0 store in R3 if zero flag is set 	//Works
		//iMem[0]=16'b0011_000_000001010;		//Load R0 with value 10*128 i.e. 1280			//Works
		//iMem[0]=16'b0100_000_001_000001;		//Load into R0 value at address (R1 + 1)		//Works
		//iMem[0]=16'b0101_010_001_000001;		//Store the contents of R1 at address (R1 + 1)	//Works
		//iMem[0]=16'b1000_010_000000011;		//JAL Store PC+1 in R2 and PC=PC+3				//Works without delay
		//iMem[0]=16'b1001_010_101_000000;		//JLR Store PC+1 in R2 and PC=R3(3)				//Works with 3 delays
		//iMem[1]=16'b0001_000_001_000111;		//Add 7 to contents of R0 and store in reg 1
		//iMem[0]=16'b1100_001_010_000111;		//BEQ if contents of R1 and R2 are equal then PC=PC+7	//Works
		
		//Data hazard code
		// 		    op 	 RA  RB  RC 
		//iMem[0]=16'b0000_000_001_010_000;	//R2=R0+R1
		//iMem[1]=16'b0000_010_001_011_000;	//R3=R2+R1
		//Works till here
		//iMem[0]=16'b0000_000_001_010_000;	//R2=R0+R1	
		//iMem[1]=16'b0000_000_001_011_000;	//R3=R0+R1
		//iMem[2]=16'b0000_010_001_011_000;	//R3=R2+R1
		//works till here
		//iMem[0]=16'b0000_000_001_010_000;	//R2=R0+R1	
		//iMem[1]=16'b0000_000_001_011_000;	//R3=R0+R1
		//iMem[2]=16'b0000_010_001_011_000;	//R3=R2+R3
		//R2=1,R3=1,R3=2
		//works till here
		//iMem[0]=16'b0000_000_001_010_000;	//R2=R0+R1	
		//iMem[1]=16'b0000_000_001_011_000;	//R3=R0+R1
		//iMem[2]=16'b0000_000_001_011_000;	//R3=R0+R1
		//iMem[3]=16'b0000_010_001_011_000;	//R3=R2+R1
		//R2=1,R3=1,R3=2
		//Works till here
		
		//iMem[0]=16'b0000_000_001_010_000;	//R2=R0+R1	
		//iMem[1]=16'b0100_001_001_000_000;	//LW R1=dMEM[1]
		//iMem[0]=16'b0100_001_001_000_000;	//LW R1=dMEM[1]
		//iMem[1]=16'b0000_010_001_011_000;	//R3=R2+R1
		//R2=1,R1=5,R3=6 Add delay slots for load
		
		//iMem[0]=16'b0000_000_001_010_000;	//R2=R0+R1	
		//iMem[1]=16'b0000_010_101_011_000;	//R3=R5+R2
		//iMem[2]=16'b0011_001_000_000_001;	//LHI R1 1 load R1 with 128
		//iMem[3]=16'b0000_011_001_100_000;	//R4=R3+R1
		//RR_EX_RA=MEM_WB_RC & RR_EX_RB=EX_MEM_RA
		//R2=1,R3=6,R1=128,R4=134
		//works
		
		//iMem[0]=16'b0000_000_010_010_000;	//R2=R0+R2	
		//iMem[1]=16'b0000_101_001_101_000;	//R5=R5+R1(1)
		//iMem[2]=16'b1100_010_001_000_010;	//BEQ R1 R2 to PC+2
		//iMem[3]=16'b1000_011_111_111_101;	//JAL R3 -3
		//iMem[4]=HALT;	//hlt
		//Works
		
		//iMem[0]=16'b0000_000_001_010_000;	//R2=R0+R1	
		//iMem[1]=16'b0000_000_001_011_000;	//R3=R0+R1
		//iMem[2]=16'b0001_000_000_000_001;	//LHI R0 1 load R1 with 128
		//iMem[3]=16'b1100_010_011_001_010;	//BEQ R3 R0 to PC+10
		//R2=1,R3=1,R0=1
		//works
		
		//iMem[0]=16'b0000_000_001_010_000;	//R2=R0+R1	
		//iMem[1]=16'b0000_000_001_011_000;	//R3=R0+R1
		//iMem[2]=16'b0000_000_001_100_000;	//R4=R0+R1
		//iMem[3]=16'b0100_000_100_000_000;	//LW R0=mem[R2+1]	
		//Works for all cases of forwarding
		
		//iMem[0]=16'b0100_000_010_000_000;	//LW R0=mem[R2+0]
		//iMem[1]=16'b0000_001_001_010_000;	//R2=R1+R1
		//iMem[2]=16'b0000_000_001_010_000;	//R2=R0+R1
		//R0=2,R2=2,R2=3
		//Works
		
		//iMem[0]=16'b0100_000_010_000_000;	//LW R0=mem[R2+0]
		//iMem[1]=16'b0000_000_001_010_000;	//R2=R1+R0
		//iMem[2]=16'b0000_000_001_010_000;	//R2=R1+R0
		//R0=2,R2=3,R2=3
		//works
		
		
		//NOP instruction
		// 16'b1111_0000_0000_0000;
		
		iMem[0]=16'b1100_001_010_000111;
		iMem[1]=16'b0000_000_001_010_000;	//R2=R0+R1
		iMem[2]=16'b0000_010_001_011_000;	//R3=R2+R1
		iMem[3]=16'b0000_000_001_010_000;	//R2=R0+R1
		iMem[4]=16'b0000_000_001_010_000;	//R2=R0+R1
		iMem[5]=16'b0000_000_001_010_000;	//R2=R0+R1
		iMem[6]=16'b0000_000_001_010_000;	//R2=R0+R1
		iMem[7]=16'b0000_000_001_010_000;	//R2=R0+R1
		iMem[8]=16'b0000_011_001_100_000;	//R4=R3+R1
		iMem[9]=16'b0000_011_001_100_000;	//R4=R3+R1
		iMem[10]=16'b0000_011_001_100_000;	//R4=R3+R1
		iMem[11]=16'b0000_011_001_100_000;	//R4=R3+R1
		//Works
		
		HALTED=1'b0;
		MEM_WB_TAKEN_BRANCH=1'b1;
		itsthatcase=1'b0;
		
	end
		
	
	always @(posedge clk1) // IF Stage
	 if (HALTED == 0)
	 begin
		 if ((EX_MEM_IR[15:12] == BEQ) && (EX_MEM_cond !=EX_MEM_H))// Takeen Branch was not correct																
		 begin	
			 
			 IF_ID_IR <=  iMem[EX_MEM_ALUOut];							//If Branch was taken then take the next instruction from mem with EX_MEM_ALUOut as address
			 EX_MEM_TAKEN_BRANCH <= 1'b1;
			 RR_EX_TAKEN_BRANCH <=  1'b1;
			 ID_RR_TAKEN_BRANCH <=  1'b1;
			 
			 //IF_ID_TAKEN_BRANCH <= 1'b0;
			 MEM_WB_TAKEN_BRANCH <= EX_MEM_TAKEN_BRANCH;
			 if(EX_MEM_H==1'b0)
			 begin
			 //Do changes to BHT
				found=0;
				 for(i=0;i<16;i=i+1)
				 begin
					if(BHT[i][16:1]==(ID_RR_NPC-1))
					begin
						found=1;
						pos=i;
						
					end
				 end
				if(found==1) BHT[pos][0]=0;
				//Do changes to PC		
				NPC<=EX_MEM_NPC  + EX_MEM_IR[5:0];
				IF_ID_NPC <=  EX_MEM_NPC  + EX_MEM_IR[5:0];
				PC <=  EX_MEM_NPC - 1 + EX_MEM_IR[5:0];

			 end	
			 else //if EX_MEM_H==1
			 begin
				//Do changes to BHT
				found=0;
				 for(i=0;i<16;i=i+1)
				 begin
					if(BHT[i][16:1]==(ID_RR_NPC-1))
					begin
						found=1;
						pos=i;
						
					end
				 end
				if(found==1) BHT[pos][0]=0;
				else if(INDEX!=MRU) 
				begin
					BHT[INDEX]<={EX_MEM_NPC-1,1'b0};
					MRU<=INDEX;
					if(INDEX==15) INDEX<=0;
					else INDEX<=INDEX+1;
				end
				else //MRU and INDEX are same, store at INDEX+1
				begin
					BHT[INDEX+1]<={EX_MEM_NPC-1,1'b0};
					MRU<=INDEX+1;
					if(INDEX==15) 
					begin
						BHT[0]<={EX_MEM_NPC-1,1'b1};
						MRU<=0;
						INDEX<=1;
					end
					else 
					begin
						BHT[INDEX+1]<={EX_MEM_NPC-1,1'b1};
						MRU<=INDEX+1;
						INDEX<=INDEX+2;
					end
				end 
				//Do changes to PC		
				NPC<=EX_MEM_NPC  + 1;
				IF_ID_NPC <=  EX_MEM_NPC  + 1;
				PC <=  EX_MEM_NPC ;
			 end
		 end
		 else if(IF_ID_IR[15:12] == JAL)  //Faster no delay slot/useless instruction
		 begin
			IF_ID_IR <=  iMem[(IF_ID_NPC-16'd1) + {{7{IF_ID_IR[8]}},IF_ID_IR[8:0]}];
			//IF_ID_TAKEN_BRANCH <=  1'b1;
			//ID_RR_NPC<=  IF_ID_NPC;
			PC<=  ((IF_ID_NPC-16'd1) + {{7{IF_ID_IR[8]}},IF_ID_IR[8:0]});
			NPC<=((IF_ID_NPC-16'd1) + {{7{IF_ID_IR[8]}},IF_ID_IR[8:0]}+16'd1);
			IF_ID_NPC<=((IF_ID_NPC-16'd1) + {{7{IF_ID_IR[8]}},IF_ID_IR[8:0]}+16'd1);
			 //IF_ID_TAKEN_BRANCH <= 1'b0;		 
			 ID_RR_TAKEN_BRANCH <=  1'b0;				 	
			 RR_EX_TAKEN_BRANCH <=  ID_RR_TAKEN_BRANCH;
			 EX_MEM_TAKEN_BRANCH <=  RR_EX_TAKEN_BRANCH;
			 MEM_WB_TAKEN_BRANCH <= EX_MEM_TAKEN_BRANCH;
			
		 end
		 /* else if(IF_ID_IR[15:12] == JAL)  //with useless instruction.
		 begin
			//IF_ID_IR <=  iMem[(IF_ID_NPC-16'd1) + {{7{IF_ID_IR[8]}},IF_ID_IR[8:0]}];
			//IF_ID_TAKEN_BRANCH <=  1'b1;
			//ID_RR_NPC<=  IF_ID_NPC;
			PC<=  ((IF_ID_NPC-16'd1) + {{7{IF_ID_IR[8]}},IF_ID_IR[8:0]});
			NPC<=((IF_ID_NPC-16'd1) + {{7{IF_ID_IR[8]}},IF_ID_IR[8:0]}+16'd1);
			IF_ID_NPC<=((IF_ID_NPC-16'd1) + {{7{IF_ID_IR[8]}},IF_ID_IR[8:0]}+16'd1);
			IF_ID_IR <= iMem[NPC];
			 //IF_ID_TAKEN_BRANCH <= 1'b0;		 
			 IF_ID_TAKEN_BRANCH <=  1'b1;
			 ID_RR_TAKEN_BRANCH <= 1'b0;	
			 RR_EX_TAKEN_BRANCH <=  ID_RR_TAKEN_BRANCH;
			 EX_MEM_TAKEN_BRANCH <=  RR_EX_TAKEN_BRANCH;
			 MEM_WB_TAKEN_BRANCH <= EX_MEM_TAKEN_BRANCH;
			
		 end */
		 else if(RR_EX_IR[15:12] == JLR)
		 begin
			IF_ID_IR <=  iMem[RR_EX_B];
			RR_EX_TAKEN_BRANCH <= 1'b1;
			ID_RR_TAKEN_BRANCH <=  1'b1;
			
			//IF_ID_TAKEN_BRANCH <= 1'b0;			 
			EX_MEM_TAKEN_BRANCH <=  RR_EX_TAKEN_BRANCH;
			MEM_WB_TAKEN_BRANCH <= EX_MEM_TAKEN_BRANCH;
			//Reg[ID_RR_IR[11:9]]<=  IF_ID_NPC;
			NPC<=RR_EX_B+16'd1;
			IF_ID_NPC<=RR_EX_B+16'd1;
			PC<=   RR_EX_B;
		 end
		 else if ((ID_RR_IR[15:12] == BEQ)) //If instruction is branch instruction then assume it as taken																
		 begin	
			 //Take care of BHT
			 found=0;
			 for(i=0;i<16;i=i+1)
			 begin
				if(BHT[i][16:1]==(ID_RR_NPC-1))
				begin
					found=1;
					pos=i;
					
				end
			 end
			 if(found==1'b1 && BHT[pos][0]==1'b1)
			 begin
				 IF_ID_IR <=  iMem[IF_ID_NPC-1+ID_RR_IR[5:0]]; // target address is PC+imm 
				 ID_RR_TAKEN_BRANCH <=  1'b0;				 	
				 RR_EX_TAKEN_BRANCH <=  ID_RR_TAKEN_BRANCH;
				 EX_MEM_TAKEN_BRANCH <=  RR_EX_TAKEN_BRANCH;
				 MEM_WB_TAKEN_BRANCH <= EX_MEM_TAKEN_BRANCH;
				 NPC<=ID_RR_NPC + ID_RR_IR[5:0];
				 IF_ID_NPC <=  ID_RR_NPC + ID_RR_IR[5:0];
				 PC <=  ID_RR_NPC + ID_RR_IR[5:0] - 1;
				 ID_RR_H<=1'b1;
			 end
			 else if(found==1'b1 && BHT[pos][0]==1'b0)
			 begin
				 IF_ID_IR <=  iMem[IF_ID_NPC]; // target address is PC+imm 
				 ID_RR_TAKEN_BRANCH <=  1'b0;				 	
				 RR_EX_TAKEN_BRANCH <=  ID_RR_TAKEN_BRANCH;
				 EX_MEM_TAKEN_BRANCH <=  RR_EX_TAKEN_BRANCH;
				 MEM_WB_TAKEN_BRANCH <= EX_MEM_TAKEN_BRANCH;
				 NPC<=ID_RR_NPC + ID_RR_IR[5:0];
				 IF_ID_NPC <=  ID_RR_NPC + ID_RR_IR[5:0];
				 PC <=  ID_RR_NPC + ID_RR_IR[5:0] - 1;
				 ID_RR_H<=1'b0;
			 end
			 else
			 begin
				//Take care of pc and npc
				IF_ID_IR <=  iMem[IF_ID_NPC-1+ID_RR_IR[5:0]]; // target address is PC+imm 
				ID_RR_TAKEN_BRANCH <=  1'b0;				 	
				RR_EX_TAKEN_BRANCH <=  ID_RR_TAKEN_BRANCH;
				EX_MEM_TAKEN_BRANCH <=  RR_EX_TAKEN_BRANCH;
				MEM_WB_TAKEN_BRANCH <= EX_MEM_TAKEN_BRANCH;
				NPC<=ID_RR_NPC + ID_RR_IR[5:0];
				IF_ID_NPC <=  ID_RR_NPC + ID_RR_IR[5:0];
				PC <=  ID_RR_NPC + ID_RR_IR[5:0] - 1;
				ID_RR_H<=1'b1;
				//take care of BHT
				if(INDEX!=MRU) 
				begin
					BHT[INDEX]<={ID_RR_NPC-1,1'b1};
					MRU<=INDEX;
					if(INDEX==15) INDEX<=0;
					else INDEX<=INDEX+1;
				end
				else //MRU and INDEX are same, store at INDEX+1
				begin
					BHT[INDEX+1]<={ID_RR_NPC-1,1'b1};
					MRU<=INDEX+1;
					if(INDEX==15) 
					begin
						BHT[0]<={ID_RR_NPC-1,1'b1};
						MRU<=0;
						INDEX<=1;
					end
					else 
					begin
						BHT[INDEX+1]<={ID_RR_NPC-1,1'b1};
						MRU<=INDEX+1;
						INDEX<=INDEX+2;
					end
				end
			 end
			 
		 end
		 else
		 begin															//Normal Instruction fetch
			 if(IF_ID_IR[15:12] != LW)IF_ID_IR <=  iMem[NPC];
			 else IF_ID_IR <= 16'b1111_0000_0000_0000;
			 if(IF_ID_IR[15:12] != LW)IF_ID_NPC <=  NPC + 1'd1;
			 if(IF_ID_IR[15:12] != LW)PC <=  PC + 1'd1;
			 if(IF_ID_IR[15:12] != LW)NPC <=  NPC + 1'd1;
			 //IF_ID_TAKEN_BRANCH <= 1'b0;
			ID_RR_H<=1'b0;
			case (IF_ID_IR[15:12])
				 ADD: ID_RR_TAKEN_BRANCH <=  1'b0;			 
				 NDU: ID_RR_TAKEN_BRANCH <=  1'b0;				 
				 ADI: ID_RR_TAKEN_BRANCH <=  1'b0;				 
				 LHI: ID_RR_TAKEN_BRANCH <=  1'b0;				 
				 LW: ID_RR_TAKEN_BRANCH <=  1'b0;				 
				 SW: ID_RR_TAKEN_BRANCH <=  1'b1;				 
				 LM: ID_RR_TAKEN_BRANCH <=  1'b0;				 
				 SM: ID_RR_TAKEN_BRANCH <=  1'b1;				 
				 BEQ: ID_RR_TAKEN_BRANCH <=  1'b1;				 
				 JAL: ID_RR_TAKEN_BRANCH <=  1'b0;				 
				 JLR: ID_RR_TAKEN_BRANCH <=  1'b0;
				 NOP: ID_RR_TAKEN_BRANCH <=  1'b1;
			 endcase
			 
			 RR_EX_TAKEN_BRANCH <=  ID_RR_TAKEN_BRANCH;
			 EX_MEM_TAKEN_BRANCH <=  RR_EX_TAKEN_BRANCH;
			 MEM_WB_TAKEN_BRANCH <= EX_MEM_TAKEN_BRANCH;
			 /*Remember to take care of zero and carry instructions */
		 end
		 
	 end
	
	always @(posedge clk1) // ID Stage
	 if (HALTED == 0)
	 begin
		 
		 ID_RR_NPC <=  IF_ID_NPC;		//forwarding
		 ID_RR_IR <=  IF_ID_IR;
		 
		 ID_RR_RA <=  IF_ID_IR[11:9];
		 ID_RR_RB <=  IF_ID_IR[8:6];
		 ID_RR_RC <=  IF_ID_IR[5:3];
		 
		 
	
		 
		 //ID_RR_TAKEN_BRANCH <= IF_ID_TAKEN_BRANCH;
		 case (IF_ID_IR[15:12])			//actual decoding
			 //RR_ALU,RI_ALU,I_LOAD,RI_LS,RI_STORE,LM_T,SM_T,BRANCH,JUMP,HALT
			 
			 ADD: ID_RR_type <=  RR_ALU;
			 
			 NDU: ID_RR_type <=  RR_ALU;
			 
			 ADI: ID_RR_type <=  RI_ALU_A;
			 
			 LHI: ID_RR_type <=  RI_ALU_L;
			 
			 LW: ID_RR_type <=  RI_L;
			 
			 SW: ID_RR_type <=  RI_S;
			 
			 LM: ID_RR_type <=  LM_T;
			 
			 SM: ID_RR_type <=  SM_T;
			 
			 BEQ: ID_RR_type <=  BRANCH;
			 
			 JAL: ID_RR_type <=  JUMP;
			 
			 JLR: ID_RR_type <=  JUMP;
			 
			 HLT: HALTED <=  1'b1;
			
			 default: ID_RR_type <=  4'bxxxx;
		 // Invalid opcode
		 endcase
	 end
	
	always @(posedge clk1) // RR Stage
	if (HALTED == 0)
	begin
		RR_EX_H<=ID_RR_H;
		RR_EX_NPC <=  ID_RR_NPC;		//forwarding
		RR_EX_IR <=  ID_RR_IR;
		RR_EX_Imm <=  ID_RR_IR[8:0];	//sign extension
		RR_EX_type <=  ID_RR_type;
		//RR_EX_TAKEN_BRANCH <= ID_RR_TAKEN_BRANCH;
		RR_EX_A <=  Reg[ID_RR_IR[11:9]]; // Read A from the reg file
		
		RR_EX_RA <= ID_RR_RA;
		RR_EX_RB <= ID_RR_RB;
		RR_EX_RC <= ID_RR_RC;
		
		 if (ID_RR_IR[15:12] ==LHI || ID_RR_IR[15:12] ==LM || ID_RR_IR[15:12] ==SM || ID_RR_IR[15:12] ==JAL) RR_EX_B <= 0; //second reg read
		 else RR_EX_B <=  Reg[ID_RR_IR[8:6]]; // "rt"	
	end
	
	always @(posedge clk1) // EX Stage
	 if (HALTED == 0)
	 begin
		 EX_MEM_H<=ID_RR_H;
		 EX_MEM_type <=  RR_EX_type; //forwarding
		 EX_MEM_IR <=  RR_EX_IR;
	     Ex_MEM_Imm <=  RR_EX_Imm;
		 EX_MEM_NPC <=  RR_EX_NPC;
		 EX_MEM_RA <= RR_EX_RA;
		 EX_MEM_RB <= RR_EX_RB;
		 EX_MEM_RC <= RR_EX_RC;
		 
		 //EX_MEM_TAKEN_BRANCH<= RR_EX_TAKEN_BRANCH;
		 
		 
		 
		 case (RR_EX_type)
			 RR_ALU: //Alu and inputs from Registers A and B 
			 begin			 
				 case (RR_EX_IR[15:12]) // "opcode"
					 ADD: begin
								//both matching operands
								if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + MEM_WB_ALUOut;								
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + WB_ALUOut;
								else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + WB_ALUOut;								
								else if(((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + MEM_WB_ALUOut;
								else if(((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + MEM_WB_ALUOut;													
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + MEM_WB_ALUOut;								
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + WB_ALUOut;
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + WB_ALUOut;								
								else if(((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + MEM_WB_ALUOut;
								else if(((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + MEM_WB_ALUOut;								
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(WB_RA==RR_EX_RA && (WB_type==JUMP ||  WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + WB_ALUOut;
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(WB_RA==RR_EX_RB && (WB_type==JUMP ||  WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + WB_ALUOut;								
								else if(((WB_RA==RR_EX_RB && (WB_type==JUMP ||  WB_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + MEM_WB_ALUOut;
								else if(((WB_RA==RR_EX_RA && (WB_type==JUMP ||  WB_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;
								else if(((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;
								else if(((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;
								else if(((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;
								else if(((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;
								else if(((WB_RA==RR_EX_RB && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;
								else if(((WB_RA==RR_EX_RB && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;								
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;								
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;								
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;								
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;								
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + MEM_WB_ALUOut;								
								else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RB==RR_EX_RB && (WB_type==RR_ALU))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;										
								else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RA==RR_EX_RB && (WB_type==JUMP || WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;										
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;										
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(WB_RB==RR_EX_RB && (WB_type==RI_ALU_A ))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;										
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;										
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + WB_ALUOut;										
								else if(((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;													
								else if(((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;													
								else if(((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;													
								else if(((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;													
								else if(((WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;													
								else if(((WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + MEM_WB_ALUOut;													
								
								//single match
								else if((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11)))) && (EX_MEM_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + RR_EX_B;
								else if((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11)))) && (EX_MEM_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + RR_EX_A;
								else if((MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11)))) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   MEM_WB_ALUOut + RR_EX_B;
								else if((MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11)))) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   MEM_WB_ALUOut + RR_EX_A;
								else if((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11)))) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + RR_EX_B;
								else if((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11)))) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + RR_EX_A;
																													
								else if((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A)) && (EX_MEM_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + RR_EX_B;
								else if((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A)) && (EX_MEM_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + RR_EX_A;
								else if((MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A)) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   MEM_WB_ALUOut + RR_EX_B;
								else if((MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A)) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   MEM_WB_ALUOut + RR_EX_A;
								else if((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A)) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + RR_EX_B;
								else if((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A)) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + RR_EX_A;
																													
								else if((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L)) && (EX_MEM_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + RR_EX_B;
								else if((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L)) && (EX_MEM_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   EX_MEM_ALUOut + RR_EX_A;
								else if((MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   MEM_WB_ALUOut + RR_EX_B;
								else if((MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   MEM_WB_ALUOut + RR_EX_A;
								else if((WB_RA==RR_EX_RA && (WB_type==JUMP ||  WB_type==RI_ALU_L)) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + RR_EX_B;
								else if((WB_RA==RR_EX_RB && (WB_type==JUMP ||  WB_type==RI_ALU_L)) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=   WB_ALUOut + RR_EX_A;
								
								else if((MEM_WB_RA==RR_EX_RA && (MEM_WB_type==RI_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <= MEM_WB_LMD + RR_EX_B;
								else if((MEM_WB_RA==RR_EX_RB && (MEM_WB_type==RI_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <= MEM_WB_LMD + RR_EX_A;
								else if((WB_RA==RR_EX_RA && (WB_type==RI_L)) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <= WB_LMD + RR_EX_B;
								else if((WB_RA==RR_EX_RB && (WB_type==RI_L)) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <= WB_LMD + RR_EX_A;
								
								
								else {EX_MEM_carry,EX_MEM_ALUOut} <=  RR_EX_A + RR_EX_B;
								EX_MEM_zero = #1 EX_MEM_zero; 
								EX_MEM_zero <= (EX_MEM_ALUOut==1'b0);
								//EX_MEM_zero <= ((RR_EX_A + RR_EX_B)==1'b0);			
						  end
					 /* ADI: begin
								{EX_MEM_carry,EX_MEM_ALUOut} <=  RR_EX_A + {10'd0,RR_EX_IR[5:0]};
								EX_MEM_zero <=((RR_EX_A + {10'd0,RR_EX_IR[5:0]})==1'b0);
						  end */					 
					 NDU: begin
								
									//EX_MEM_ALUOut <=  ~(RR_EX_A & RR_EX_B);
								if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & MEM_WB_ALUOut);
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & MEM_WB_ALUOut);								
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & WB_ALUOut);
								else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & WB_ALUOut);								
								else if(((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(WB_ALUOut & MEM_WB_ALUOut);
								else if(((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(WB_ALUOut & MEM_WB_ALUOut);													
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & MEM_WB_ALUOut);
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & MEM_WB_ALUOut);								
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & WB_ALUOut);
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & WB_ALUOut);								
								else if(((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(WB_ALUOut & MEM_WB_ALUOut);
								else if(((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(WB_ALUOut & MEM_WB_ALUOut);													
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & MEM_WB_ALUOut);
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & MEM_WB_ALUOut);								
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(WB_RA==RR_EX_RA && (WB_type==JUMP ||  WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & WB_ALUOut);
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(WB_RA==RR_EX_RB && (WB_type==JUMP ||  WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & WB_ALUOut);								
								else if(((WB_RA==RR_EX_RB && (WB_type==JUMP ||  WB_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(WB_ALUOut & MEM_WB_ALUOut);
								else if(((WB_RA==RR_EX_RA && (WB_type==JUMP ||  WB_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <= ~(WB_ALUOut & MEM_WB_ALUOut);													
								else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);
								else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);
								else if(((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);
								else if(((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);
								else if(((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);
								else if(((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);
								else if(((WB_RA==RR_EX_RB && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);
								else if(((WB_RA==RR_EX_RB && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);								
								else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);								
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);								
								else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);								
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);								
								else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & MEM_WB_ALUOut);								
								else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RB==RR_EX_RB && (WB_type==RR_ALU))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);										
								else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RA==RR_EX_RB && (WB_type==JUMP || WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);										
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);										
								else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(WB_RB==RR_EX_RB && (WB_type==RI_ALU_A ))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);										
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);										
								else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(EX_MEM_ALUOut & WB_ALUOut);										
								else if(((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);													
								else if(((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);													
								else if(((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);													
								else if(((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);													
								else if(((WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);													
								else if(((WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) EX_MEM_ALUOut <=~(WB_ALUOut & MEM_WB_ALUOut);													
								
								//single match 
								else if((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11)))) && (EX_MEM_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & RR_EX_B);
								else if((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11)))) && (EX_MEM_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & RR_EX_A);
								else if((MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11)))) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(MEM_WB_ALUOut & RR_EX_B);
								else if((MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11)))) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(MEM_WB_ALUOut & RR_EX_A);
								else if((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11)))) && (WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(WB_ALUOut & RR_EX_B);
								else if((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11)))) && (WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(WB_ALUOut & RR_EX_A);
								
								else if((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A)) && (EX_MEM_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & RR_EX_B);
								else if((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A)) && (EX_MEM_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & RR_EX_A);
								else if((MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A)) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(MEM_WB_ALUOut & RR_EX_B);
								else if((MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A)) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(MEM_WB_ALUOut & RR_EX_A);
								else if((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A)) && (WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(WB_ALUOut & RR_EX_B);
								else if((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A)) && (WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(WB_ALUOut & RR_EX_A);
								
								else if((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L)) && (EX_MEM_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & RR_EX_B);
								else if((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L)) && (EX_MEM_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(EX_MEM_ALUOut & RR_EX_A);
								else if((MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(MEM_WB_ALUOut & RR_EX_B);
								else if((MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(MEM_WB_ALUOut & RR_EX_A);
								else if((WB_RA==RR_EX_RA && (WB_type==JUMP ||  WB_type==RI_ALU_L)) && (WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(WB_ALUOut & RR_EX_B);
								else if((WB_RA==RR_EX_RB && (WB_type==JUMP ||  WB_type==RI_ALU_L)) && (WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(WB_ALUOut & RR_EX_A);
								
								else if((MEM_WB_RA==RR_EX_RA && (MEM_WB_type==RI_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(MEM_WB_LMD & RR_EX_B);
								else if((MEM_WB_RA==RR_EX_RB && (MEM_WB_type==RI_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <= ~(MEM_WB_LMD & RR_EX_A);
								
								else if((MEM_WB_RA==RR_EX_RA && (MEM_WB_type==RI_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <= ~(MEM_WB_LMD & RR_EX_B);
								else if((MEM_WB_RA==RR_EX_RB && (MEM_WB_type==RI_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <= ~(MEM_WB_LMD & RR_EX_A);
								else if((WB_RA==RR_EX_RA && (WB_type==RI_L)) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <= ~(WB_LMD & RR_EX_B);
								else if((WB_RA==RR_EX_RB && (WB_type==RI_L)) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <= ~(WB_LMD & RR_EX_A);
								
							
								else EX_MEM_ALUOut <=  ~(RR_EX_A & RR_EX_B);								

								
								EX_MEM_zero = #1 EX_MEM_zero; 
								//EX_MEM_zero <=(~(RR_EX_A & RR_EX_B)==1'b0);	
								EX_MEM_zero =(EX_MEM_ALUOut==1'b0);	
						  end	
					 default: EX_MEM_ALUOut <=  16'hxxxx;
				 endcase
			 end

			 RI_ALU_A: //ADI instruction
			 begin		
						if((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11)))) && (EX_MEM_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + {{10{RR_EX_Imm[8]}},RR_EX_Imm[5:0]};
						else if((MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11)))) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=  MEM_WB_ALUOut + {{10{RR_EX_Imm[8]}},RR_EX_Imm[5:0]};
						else if((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11)))) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + {{10{RR_EX_Imm[8]}},RR_EX_Imm[5:0]};
						else if((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A)) && (EX_MEM_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + {{10{RR_EX_Imm[8]}},RR_EX_Imm[5:0]};
						else if((MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A)) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=  MEM_WB_ALUOut + {{10{RR_EX_Imm[8]}},RR_EX_Imm[5:0]};
						else if((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A)) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + {{10{RR_EX_Imm[8]}},RR_EX_Imm[5:0]};
						else if((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L)) && (EX_MEM_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=  EX_MEM_ALUOut + {{10{RR_EX_Imm[8]}},RR_EX_Imm[5:0]};
						else if((MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=  MEM_WB_ALUOut + {{10{RR_EX_Imm[8]}},RR_EX_Imm[5:0]};
						else if((WB_RA==RR_EX_RA && (WB_type==JUMP ||  WB_type==RI_ALU_L)) && (WB_TAKEN_BRANCH==1'b0)) {EX_MEM_carry,EX_MEM_ALUOut} <=  WB_ALUOut + {{10{RR_EX_Imm[8]}},RR_EX_Imm[5:0]};
						else {EX_MEM_carry,EX_MEM_ALUOut} <=  RR_EX_A + {{10{RR_EX_Imm[8]}},RR_EX_Imm[5:0]};
						//add dependence on LW here
						
						EX_MEM_zero=#1 EX_MEM_zero;
						EX_MEM_zero <=  (EX_MEM_ALUOut==16'd0);
			 end

			RI_ALU_L: EX_MEM_ALUOut <=  {RR_EX_IR[8:0],7'd0}; //No data hazard :)

			 //Done till here
			 RI_L,RI_S:
			 begin
				if((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11)))) && (EX_MEM_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <=  EX_MEM_ALUOut + {10'd0,RR_EX_Imm[5:0]};
				else if((MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11)))) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <=  MEM_WB_ALUOut + {10'd0,RR_EX_Imm[5:0]};
				else if((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11)))) && (WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <=  WB_ALUOut + {10'd0,RR_EX_Imm[5:0]};				
				else if((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A)) && (EX_MEM_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <=  EX_MEM_ALUOut + {10'd0,RR_EX_Imm[5:0]};
				else if((MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A)) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <=  MEM_WB_ALUOut + {10'd0,RR_EX_Imm[5:0]};
				else if((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A)) && (WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <=  WB_ALUOut + {10'd0,RR_EX_Imm[5:0]};
				else if((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L)) && (EX_MEM_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <=  EX_MEM_ALUOut + {10'd0,RR_EX_Imm[5:0]};
				else if((MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <=  MEM_WB_ALUOut + {10'd0,RR_EX_Imm[5:0]};
				else if((WB_RA==RR_EX_RB && (WB_type==JUMP ||  WB_type==RI_ALU_L)) && (WB_TAKEN_BRANCH==1'b0)) EX_MEM_ALUOut <=  WB_ALUOut + {10'd0,RR_EX_Imm[5:0]};
				else EX_MEM_ALUOut <=  RR_EX_B + {10'd0,RR_EX_Imm[5:0]};
				
				//add dependence on lw here
				
				EX_MEM_B <=  RR_EX_B;
			 end
			 
			 BRANCH: 
			 begin
				
				if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;								
				else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;								
				else if(((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;													
				else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;							
				else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;							
				else if(((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;												
				else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;								
				else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(WB_RA==RR_EX_RA && (WB_type==JUMP ||  WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(WB_RA==RR_EX_RB && (WB_type==JUMP ||  WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;								
				else if(((WB_RA==RR_EX_RB && (WB_type==JUMP ||  WB_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((WB_RA==RR_EX_RA && (WB_type==JUMP ||  WB_type==RI_ALU_L))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;													
				else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(EX_MEM_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((WB_RA==RR_EX_RB && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((WB_RA==RR_EX_RB && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;								
				else if(((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;								
				else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;							
				else if(((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;								
				else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;								
				else if(((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(MEM_WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;								
				else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RB==RR_EX_RB && (WB_type==RR_ALU))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;										
				else if(((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11))))&&(WB_RA==RR_EX_RB && (WB_type==JUMP || WB_type==RI_ALU_L))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;											
				else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;											
				else if(((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A))&&(WB_RB==RR_EX_RB && (WB_type==RI_ALU_A ))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;											
				else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;											
				else if(((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP || EX_MEM_type==RI_ALU_L))&&(WB_RB==RR_EX_RB && (WB_type==RI_ALU_A))) && ((EX_MEM_TAKEN_BRANCH==1'b0)&&(WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;											
				else if(((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;														
				else if(((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11))))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;													
				else if(((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;													
				
				else if((EX_MEM_RC==RR_EX_RA && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11)))) && (EX_MEM_TAKEN_BRANCH==1'b0)) if(EX_MEM_ALUOut==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((EX_MEM_RC==RR_EX_RB && (EX_MEM_type==RR_ALU &&((EX_MEM_IR[1:0]==2'b10 && EX_MEM_carry==1) || (EX_MEM_IR[1:0]==2'b01 && EX_MEM_zero==1) || (EX_MEM_IR[1:0]==2'b00 || EX_MEM_IR[1:0]==2'b11)))) && (EX_MEM_TAKEN_BRANCH==1'b0)) if(RR_EX_A==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((MEM_WB_RC==RR_EX_RA && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11)))) && (MEM_WB_TAKEN_BRANCH==1'b0)) if(MEM_WB_ALUOut==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11)))) && (MEM_WB_TAKEN_BRANCH==1'b0)) if(RR_EX_A==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((WB_RC==RR_EX_RA && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11)))) && (WB_TAKEN_BRANCH==1'b0)) if(WB_ALUOut==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((WB_RC==RR_EX_RB && (WB_type==RR_ALU &&((WB_IR[1:0]==2'b10 && WB_carry==1) || (WB_IR[1:0]==2'b01 && WB_zero==1) || (WB_IR[1:0]==2'b00 || WB_IR[1:0]==2'b11)))) && (WB_TAKEN_BRANCH==1'b0)) if(RR_EX_A==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				//MEM_WB_RC=RR_EX_RB & WB_RC=RR_EX_RA
				else if((EX_MEM_RB==RR_EX_RA && (EX_MEM_type==RI_ALU_A)) && (EX_MEM_TAKEN_BRANCH==1'b0)) if(EX_MEM_ALUOut==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((EX_MEM_RB==RR_EX_RB && (EX_MEM_type==RI_ALU_A)) && (EX_MEM_TAKEN_BRANCH==1'b0)) if(RR_EX_A==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((MEM_WB_RB==RR_EX_RA && (MEM_WB_type==RI_ALU_A)) && (MEM_WB_TAKEN_BRANCH==1'b0)) if(MEM_WB_ALUOut==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_A)) && (MEM_WB_TAKEN_BRANCH==1'b0)) if(RR_EX_A==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A)) && (WB_TAKEN_BRANCH==1'b0)) if(WB_ALUOut==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((WB_RB==RR_EX_RB && (WB_type==RI_ALU_A)) && (WB_TAKEN_BRANCH==1'b0)) if(RR_EX_A==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				
				else if((EX_MEM_RA==RR_EX_RA && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L)) && (EX_MEM_TAKEN_BRANCH==1'b0)) if(EX_MEM_ALUOut==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((EX_MEM_RA==RR_EX_RB && (EX_MEM_type==JUMP ||  EX_MEM_type==RI_ALU_L)) && (EX_MEM_TAKEN_BRANCH==1'b0)) if(RR_EX_A==EX_MEM_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((MEM_WB_RA==RR_EX_RA && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) if(MEM_WB_ALUOut==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP ||  MEM_WB_type==RI_ALU_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) if(RR_EX_A==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((WB_RA==RR_EX_RA && (WB_type==JUMP ||  WB_type==RI_ALU_L)) && (WB_TAKEN_BRANCH==1'b0)) if(WB_ALUOut==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((WB_RA==RR_EX_RB && (WB_type==JUMP ||  WB_type==RI_ALU_L)) && (WB_TAKEN_BRANCH==1'b0)) if(RR_EX_A==WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				
				else if(((WB_RB==RR_EX_RA && (WB_type==RI_ALU_A))&&(MEM_WB_RA==RR_EX_RB && (MEM_WB_type==JUMP || MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;													
				else if(((WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RC==RR_EX_RB && (MEM_WB_type==RR_ALU &&((MEM_WB_IR[1:0]==2'b10 && MEM_WB_carry==1) || (MEM_WB_IR[1:0]==2'b01 && MEM_WB_zero==1) || (MEM_WB_IR[1:0]==2'b00 || MEM_WB_IR[1:0]==2'b11))))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;													
				else if(((WB_RA==RR_EX_RA && (WB_type==JUMP || WB_type==RI_ALU_L))&&(MEM_WB_RB==RR_EX_RB && (MEM_WB_type==RI_ALU_L))) && ((WB_TAKEN_BRANCH==1'b0)&&(MEM_WB_TAKEN_BRANCH==1'b0))) if(WB_ALUOut==MEM_WB_ALUOut) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;													
				
				else if((MEM_WB_RA==RR_EX_RA && (MEM_WB_type==RI_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) if(MEM_WB_LMD==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((MEM_WB_RA==RR_EX_RB && (MEM_WB_type==RI_L)) && (MEM_WB_TAKEN_BRANCH==1'b0)) if(MEM_WB_LMD==RR_EX_A) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((WB_RA==RR_EX_RA && (WB_type==RI_L)) && (WB_TAKEN_BRANCH==1'b0)) if(WB_LMD==RR_EX_B) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				else if((WB_RA==RR_EX_RB && (WB_type==RI_L)) && (WB_TAKEN_BRANCH==1'b0)) if(WB_LMD==RR_EX_A) EX_MEM_cond=1'b1;else EX_MEM_cond=1'b0;
				


				else if(RR_EX_A==RR_EX_B) EX_MEM_cond=1;
				else EX_MEM_cond=0;
						
				
				 EX_MEM_ALUOut <=  (RR_EX_NPC-16'd1) + {10'b0,RR_EX_Imm[5:0]};
				 
				 
			 end
			 
			 JUMP: EX_MEM_ALUOut <=  RR_EX_NPC; 
						   
			 
	     endcase
	 end 
	 
	always @(posedge clk1) // MEM Stage
	if (HALTED == 0)
	begin
		//Forwarding.
		MEM_WB_type <=  EX_MEM_type;
		MEM_WB_IR <=  EX_MEM_IR;
		MEM_WB_zero<= EX_MEM_zero;
		MEM_WB_carry<= EX_MEM_carry;
		MEM_WB_RA <= EX_MEM_RA;
		MEM_WB_RB <= EX_MEM_RB;
		MEM_WB_RC <= EX_MEM_RC;
		//MEM_WB_TAKEN_BRANCH<= EX_MEM_TAKEN_BRANCH;
		
		case (EX_MEM_type)
			RR_ALU, RI_ALU_A,RI_ALU_L: MEM_WB_ALUOut <=  EX_MEM_ALUOut; //no need of any memory access just forward.
			RI_L: MEM_WB_LMD <=  dMem[EX_MEM_ALUOut];
			RI_S: dMem[EX_MEM_ALUOut] <=  EX_MEM_B;		 
			JUMP: MEM_WB_ALUOut <=  EX_MEM_ALUOut;
		endcase
	end
	
	always @(posedge clk1) // WB Stage
		begin
		//Forwarding
		WB_RC <= MEM_WB_RC;
		WB_RA <= MEM_WB_RA;
		WB_RB <= MEM_WB_RB;
		WB_type<=MEM_WB_type;
		WB_TAKEN_BRANCH <= MEM_WB_TAKEN_BRANCH;
		WB_ALUOut <= MEM_WB_ALUOut;
		WB_IR <= MEM_WB_IR;
		WB_carry <= MEM_WB_carry;
		WB_zero <= MEM_WB_zero;
		WB_LMD<=MEM_WB_LMD;
		
		if (MEM_WB_TAKEN_BRANCH == 0) // Disable write if branch taken
		 case (MEM_WB_type)
					
			 RR_ALU: if(((MEM_WB_IR[1:0]==2'b10)&&(carry==1'b1))||((MEM_WB_IR[1:0]==2'b01)&&(zero==1'b1))||(MEM_WB_IR[1:0]==2'b00)) Reg[MEM_WB_IR[5:3]] <=  MEM_WB_ALUOut;
			 RI_ALU_A: Reg[MEM_WB_IR[8:6]] <=  MEM_WB_ALUOut;
			 RI_ALU_L: Reg[MEM_WB_IR[11:9]] <=  MEM_WB_ALUOut;
			 RI_L: Reg[MEM_WB_IR[11:9]] <=  MEM_WB_LMD;
			 JUMP: Reg[MEM_WB_IR[11:9]] <=  MEM_WB_ALUOut;
			 HALT: HALTED <=  1'b1;
		 endcase
		 
		 carry <=  MEM_WB_carry;
		 zero <=  MEM_WB_zero;
		 
		end
endmodule