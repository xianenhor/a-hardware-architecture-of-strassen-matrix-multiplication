module memory (
    input logic clk,
    input logic we,
    input logic ldmemAB,
    input logic done,
    input logic [3:0] addr,  // Only values 2, 4, or 8 expected
    input logic [11:0] dataInC [0:7][0:7],  // memC write input
    output logic [3:0] dataInA [0:7][0:7],  // memA read output
    output logic [3:0] dataInB [0:7][0:7]  // memB read output
);

    // Internal 8x8 memory matrices
    logic [3:0] memA[0:7][0:7], memB[0:7][0:7];
    logic [11:0] memC [0:7][0:7];

    // === Memory Initialization ===
    initial begin
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
                memA[i][j] = j % 8;
                memB[i][j] = j % 8;
                memC[i][j] = 0;
            end
        end
    end

    // === Write or Read Operation ===
    always_ff @(posedge clk) begin
        if (we) begin
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    if (dataInC[i][j] === 12'bx) begin
                        memC[i][j] <= 0;
                    end else
                        memC[i][j] <= dataInC[i][j];
                end
            end
        end
        else if (ldmemAB) begin
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    dataInA[i][j] <= (i < addr && j < addr) ? memA[i][j] : 0;
                    dataInB[i][j] <= (i < addr && j < addr) ? memB[i][j] : 0;
                end
            end
        end
        else if (done) begin
            $display ("\n====memC====");        
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    $write ("%d",memC[i][j], " ");
                    if (j%8 == 7) $write("\n");
                end
            end
            $display("\n");
        end
    end  
        
endmodule


// Strassens module Control Unit
module StrassenMM_CU (
    input clk, start, reset,              
    input [3:0] mode,       // Mode selector (used to choose matrix size)
    output logic done, we, ldmemAB, ldBF, ldComb2, ldSlice, ldCalc1, ldCalc2, ldComb1, clrAll,
    output  logic [3:0] addr,
    output logic [3:0] stateMM
);

    // IDLE:0
    // CHECK:1
    // SEL2:2
    // BF:3
    // SEL4:4
    // SEL8:5
    // SLICE:6
    // CALC1:7
    // CALC2:8
    // COMB1:9
    // COMB2:10
    // LOAD_C:11
    // DONE:12
    typedef enum logic [3:0] {
        IDLE, CHECK, SEL2,
        BF, // Brute Force
        SEL4, SEL8, SLICE, CALC1, CALC2, COMB1, COMB2, LOAD_C, DONE
      } state_t;   
      
      state_t PS;
      
     // state register
    always_ff@(posedge clk, posedge reset) begin
        if(reset) PS <= IDLE;
        else case(PS)
            IDLE: begin 
                    if(start) PS <= CHECK;
                    else PS <= IDLE; end
            CHECK: begin
                    if(mode==2) PS <= SEL2;
                    else if(mode==4) PS <= SEL4; 
                    else if(mode==8) PS <= SEL8; 
                    else PS <= CHECK; end
            SEL2: PS <= BF;
            SEL4: PS <= SLICE; 
            SLICE: PS <= CALC1; 
            CALC1: PS <= CALC2; 
            CALC2: PS <= COMB1;
            COMB1: PS <= COMB2;
            COMB2: PS <= LOAD_C; 
            LOAD_C: PS <= DONE; 
            BF: PS <= LOAD_C;
            DONE: PS <= IDLE;
            SEL8: PS <= SLICE;
        default: PS <= IDLE;
        endcase
    end
    
    
    // next state logic
    always_comb begin
        done=0; we=0; ldmemAB=0; ldBF=0; ldComb2=0; ldSlice=0; ldCalc1=0; ldCalc2=0; ldComb1=0; addr=0; clrAll=0; // deactivate all control signals
                
        case (PS)
            IDLE: begin clrAll=1; end
            SEL2: begin addr=2; ldmemAB=1; end
            BF: begin ldBF=1; addr=2; end
            LOAD_C: begin we=1; end
            DONE: begin done=1; end
            SEL4: begin addr=4; ldmemAB=1; end
            SEL8: begin addr=8; ldmemAB=1; end
            SLICE: begin ldSlice=1; 
                        if(mode==4) addr=4; 
                        else if(mode==8) addr=8; 
                   end
            CALC1: begin ldCalc1=1; 
                        if(mode==4) addr=4; 
                        else if(mode==8) addr=8; 
                   end
            CALC2: begin ldCalc2=1; 
                        if(mode==4) addr=4; 
                        else if(mode==8) addr=8;
                   end
            COMB1: begin ldComb1=1; 
                   end          
            COMB2: begin ldComb2=1; 
                        if(mode==4) addr=4; 
                        else if(mode==8) addr=8;            
            
                   end
        default: begin done=0; we=0; ldmemAB=0; ldBF=0; ldComb2=0; ldSlice=0; ldCalc1=0; ldCalc2=0; ldComb1=0; addr=0; clrAll=0; end
        endcase
    end


    
    assign stateMM = PS;
    
endmodule


// Strassens module Datapath Unit
module StrassenMM_DU(
    input clk,
    input [3:0] addr,
    input [3:0] dataInA [0:7][0:7],      
    input [3:0] dataInB [0:7][0:7],
    input ldBF, ldComb2, ldSlice, ldCalc1, ldCalc2, ldComb1,clrAll,
    output logic [11:0] dataOutC [0:7][0:7]
);
    
    logic [11:0] A11[0:7][0:7], A12[0:7][0:7], A21[0:7][0:7], A22[0:7][0:7], B11[0:7][0:7], B12[0:7][0:7], B21[0:7][0:7], B22[0:7][0:7];
    logic [11:0] C11[0:7][0:7], C12[0:7][0:7], C21[0:7][0:7], C22[0:7][0:7],
                 P[0:7][0:7], Q[0:7][0:7], R[0:7][0:7], S[0:7][0:7],
                 T[0:7][0:7], U[0:7][0:7], V[0:7][0:7],
                 psub1[0:7][0:7], qsub[0:7][0:7], rsub[0:7][0:7], ssub[0:7][0:7], tsub[0:7][0:7], usub1[0:7][0:7], usub2[0:7][0:7],
                 vsub1[0:7][0:7], vsub2[0:7][0:7], psub2[0:7][0:7];
    logic [11:0] tempSumP, tempSumQ, tempSumR, tempSumS, tempSumT, tempSumU, tempSumV;
    int i,j;
    
    // [set][row][col]
    logic [11:0] recursive_A11 [0:6][0:1][0:1]; 
    logic [11:0] recursive_A12 [0:6][0:1][0:1]; 
    logic [11:0] recursive_A21 [0:6][0:1][0:1]; 
    logic [11:0] recursive_A22 [0:6][0:1][0:1]; 
    logic [11:0] recursive_B11 [0:6][0:1][0:1]; 
    logic [11:0] recursive_B12 [0:6][0:1][0:1]; 
    logic [11:0] recursive_B21 [0:6][0:1][0:1]; 
    logic [11:0] recursive_B22 [0:6][0:1][0:1];     
    
    // [set][row][col]
    // 7 sets of psub1,psub2,qsub,rsub,ssub,tsub,usub1,usub2,vsub1,vsub2
    logic [11:0] recursive_psub1 [0:6][0:1][0:1]; 
    logic [11:0] recursive_psub2 [0:6][0:1][0:1];   
    logic [11:0] recursive_qsub [0:6][0:1][0:1]; 
    logic [11:0] recursive_rsub [0:6][0:1][0:1]; 
    logic [11:0] recursive_ssub [0:6][0:1][0:1]; 
    logic [11:0] recursive_tsub [0:6][0:1][0:1]; 
    logic [11:0] recursive_usub1 [0:6][0:1][0:1]; 
    logic [11:0] recursive_usub2 [0:6][0:1][0:1]; 
    logic [11:0] recursive_vsub1 [0:6][0:1][0:1]; 
    logic [11:0] recursive_vsub2 [0:6][0:1][0:1]; 

    // [set][row][col]
    // 7 sets of P,Q,R,S,T,U,V
    logic [11:0] recursive_P [0:6][0:1][0:1]; 
    logic [11:0] recursive_Q [0:6][0:1][0:1];   
    logic [11:0] recursive_R [0:6][0:1][0:1]; 
    logic [11:0] recursive_S [0:6][0:1][0:1]; 
    logic [11:0] recursive_T [0:6][0:1][0:1]; 
    logic [11:0] recursive_U [0:6][0:1][0:1]; 
    logic [11:0] recursive_V [0:6][0:1][0:1]; 


    // automatic - each output is privacy value to each function call 
    task automatic slice4x4to2x2 (
        input  logic [11:0] A [0:7][0:7],
        input  logic [11:0] B [0:7][0:7],
        output logic [11:0] A11 [0:1][0:1],
        output logic [11:0] A12 [0:1][0:1],
        output logic [11:0] A21 [0:1][0:1],
        output logic [11:0] A22 [0:1][0:1],
        output logic [11:0] B11 [0:1][0:1],
        output logic [11:0] B12 [0:1][0:1],
        output logic [11:0] B21 [0:1][0:1],
        output logic [11:0] B22 [0:1][0:1]
    );
        for (int i = 0; i < 2; i++) begin
            for (int j = 0; j < 2; j++) begin
                A11[i][j] = A[i][j];
                A12[i][j] = A[i][j+2];
                A21[i][j] = A[i+2][j];
                A22[i][j] = A[i+2][j+2];
                B11[i][j] = B[i][j];
                B12[i][j] = B[i][j+2];
                B21[i][j] = B[i+2][j];
                B22[i][j] = B[i+2][j+2];
            end
        end
    endtask


    task automatic prepare_submatrices (
        input logic [3:0] size,
        input logic [11:0] A11 [0:1][0:1],
        input logic [11:0] A12 [0:1][0:1],
        input logic [11:0] A21 [0:1][0:1],
        input logic [11:0] A22 [0:1][0:1],
        input logic [11:0] B11 [0:1][0:1],
        input logic [11:0] B12 [0:1][0:1],
        input logic [11:0] B21 [0:1][0:1],
        input logic [11:0] B22 [0:1][0:1],
        
        output logic [11:0] psub1 [0:1][0:1],
        output logic [11:0] psub2 [0:1][0:1],
        output logic [11:0] qsub  [0:1][0:1],
        output logic [11:0] rsub  [0:1][0:1],
        output logic [11:0] ssub  [0:1][0:1],
        output logic [11:0] tsub  [0:1][0:1],
        output logic [11:0] usub1 [0:1][0:1],
        output logic [11:0] usub2 [0:1][0:1],
        output logic [11:0] vsub1 [0:1][0:1],
        output logic [11:0] vsub2 [0:1][0:1]        
    );
        for (int i = 0; i < size; i++) begin
            for (int j = 0; j < size; j++) begin
                psub1[i][j] = A11[i][j] + A22[i][j];
                psub2[i][j] = B11[i][j] + B22[i][j];                
                qsub[i][j] = A21[i][j] + A22[i][j];
                rsub[i][j] = B12[i][j] - B22[i][j];
                ssub[i][j] = B21[i][j] - B11[i][j];
                tsub[i][j] = A11[i][j] + A12[i][j];
                usub1[i][j] = A21[i][j] - A11[i][j];
                usub2[i][j] = B11[i][j] + B12[i][j];
                vsub1[i][j] = A12[i][j] - A22[i][j];
                vsub2[i][j] = B21[i][j] + B22[i][j];
            end
        end
    endtask
    
    task automatic compute_strassen_products (
        input  int size,
        input  logic [11:0] psub1 [0:1][0:1],
        input  logic [11:0] psub2 [0:1][0:1],
        input  logic [11:0] qsub  [0:1][0:1],
        input  logic [11:0] B11   [0:1][0:1],
        input  logic [11:0] A11   [0:1][0:1],
        input  logic [11:0] rsub  [0:1][0:1],
        input  logic [11:0] A22   [0:1][0:1],
        input  logic [11:0] ssub  [0:1][0:1],
        input  logic [11:0] tsub  [0:1][0:1],
        input  logic [11:0] B22   [0:1][0:1],
        input  logic [11:0] usub1 [0:1][0:1],
        input  logic [11:0] usub2 [0:1][0:1],
        input  logic [11:0] vsub1 [0:1][0:1],
        input  logic [11:0] vsub2 [0:1][0:1],
    
        output logic [11:0] P [0:1][0:1],
        output logic [11:0] Q [0:1][0:1],
        output logic [11:0] R [0:1][0:1],
        output logic [11:0] S [0:1][0:1],
        output logic [11:0] T [0:1][0:1],
        output logic [11:0] U [0:1][0:1],
        output logic [11:0] V [0:1][0:1]
    );
        for (int i = 0; i < size; i++) begin
            for (int j = 0; j < size; j++) begin
                int tempSumP = 0, tempSumQ = 0, tempSumR = 0;
                int tempSumS = 0, tempSumT = 0, tempSumU = 0, tempSumV = 0;
                for (int k = 0; k < size; k++) begin
                    tempSumP += psub1[i][k] * psub2[k][j];
                    tempSumQ += qsub[i][k]  * B11[k][j];
                    tempSumR += A11[i][k]   * rsub[k][j];
                    tempSumS += A22[i][k]   * ssub[k][j];
                    tempSumT += tsub[i][k]  * B22[k][j];
                    tempSumU += usub1[i][k] * usub2[k][j];
                    tempSumV += vsub1[i][k] * vsub2[k][j];
                end
                P[i][j] = tempSumP;
                Q[i][j] = tempSumQ;
                R[i][j] = tempSumR;
                S[i][j] = tempSumS;
                T[i][j] = tempSumT;
                U[i][j] = tempSumU;
                V[i][j] = tempSumV;
            end
        end
    endtask
    
    
    task automatic combine_strassen_products (
        input  int size,  // Usually 2 or 4 for your recursive levels
        input  logic [11:0] P [0:1][0:1],
        input  logic [11:0] Q [0:1][0:1],
        input  logic [11:0] R [0:1][0:1],
        input  logic [11:0] S [0:1][0:1],
        input  logic [11:0] T [0:1][0:1],
        input  logic [11:0] U [0:1][0:1],
        input  logic [11:0] V [0:1][0:1],
        output logic [11:0] dataOutC [0:7][0:7]
    );
        for (int i = 0; i < size; i++) begin
            for (int j = 0; j < size; j++) begin
                // C11
                dataOutC[i][j] = P[i][j] + S[i][j] - T[i][j] + V[i][j];
    
                // C12
                dataOutC[i][j + size] = R[i][j] + T[i][j];
    
                // C21
                dataOutC[i + size][j] = Q[i][j] + S[i][j];
    
                // C22
                dataOutC[i + size][j + size] = P[i][j] + R[i][j] - Q[i][j] + U[i][j];
            end
        end
    endtask
        
    
    always_ff @(posedge clk) begin
        if (clrAll) begin
        // === Clear All Intermediate Registers ===  
        tempSumP<= 0; tempSumQ<= 0; tempSumR<= 0; tempSumS<= 0; tempSumT<= 0; tempSumU<= 0; tempSumV<= 0;
           for (i = 0; i < 8; i++) begin
            for (j = 0; j < 8; j++) begin
                A11[i][j] <= 0; A12[i][j] <= 0; A21[i][j] <= 0; A22[i][j] <= 0;
                B11[i][j] <= 0; B12[i][j] <= 0; B21[i][j] <= 0; B22[i][j] <= 0;
                C11[i][j] <= 0; C12[i][j] <= 0; C21[i][j] <= 0; C22[i][j] <= 0;
                P[i][j] <= 0; Q[i][j] <= 0; R[i][j] <= 0; S[i][j] <= 0;
                T[i][j] <= 0; U[i][j] <= 0; V[i][j] <= 0;
                psub1[i][j] <= 0; qsub[i][j] <= 0; rsub[i][j] <= 0; ssub[i][j] <= 0; tsub[i][j] <= 0; usub1[i][j] <= 0; usub2[i][j] <= 0;
                vsub1[i][j] <= 0; vsub2[i][j] <= 0; psub2[i][j] <= 0;
                
            end
            end
        end
     
        
         // ==== Test case: 2x2 Brute fore method ==== //
        else if (ldBF) begin
            
        for (i = 0; i < addr; i++) begin
            for (j = 0; j < addr; j++) begin
                dataOutC[i][j] <= (dataInA[i][0] * dataInB[0][j]) +
                                 (dataInA[i][1] * dataInB[1][j]);
            end
            end

        
        end
        
        
        
         // ==== Test case: 4x4, 8x8 Strassen Algorithm ==== //
        else if (ldSlice) begin
        if (addr == 4) begin
            for (i = 0; i < 2; i++) begin
                for (j = 0; j < 2; j++) begin
                    // Top-left 2x2
                    A11[i][j] <= dataInA[i][j];           // Rows 0-1, Cols 0-1
                    // Top-right 2x2
                    A12[i][j] <= dataInA[i][j + 2];       // Rows 0-1, Cols 2-3
                    // Bottom-left 2x2
                    A21[i][j] <= dataInA[i + 2][j];       // Rows 2-3, Cols 0-1
                    // Bottom-right 2x2
                    A22[i][j] <= dataInA[i + 2][j + 2];   // Rows 2-3, Cols 2-3
                    
                    B11[i][j] <= dataInB[i][j];           
                    B12[i][j] <= dataInB[i][j + 2];       
                    B21[i][j] <= dataInB[i + 2][j];       
                    B22[i][j] <= dataInB[i + 2][j + 2];   
                end
            end
        end

        else if (addr == 8) begin
            for (i = 0; i < 4; i++) begin
                for (j = 0; j < 4; j++) begin
                    // Top-left 4x4
                    A11[i][j] <= dataInA[i][j];           // Rows 0-3, Cols 0-3
                    // Top-right 4x4
                    A12[i][j] <= dataInA[i][j + 4];       // Rows 0-3, Cols 4-7
                    // Bottom-left 4x4
                    A21[i][j] <= dataInA[i + 4][j];       // Rows 4-7, Cols 0-3
                    // Bottom-right 4x4
                    A22[i][j] <= dataInA[i + 4][j + 4];   // Rows 4-7, Cols 4-7
                    
                    B11[i][j] <= dataInB[i][j];           
                    B12[i][j] <= dataInB[i][j + 4];       
                    B21[i][j] <= dataInB[i + 4][j];       
                    B22[i][j] <= dataInB[i + 4][j + 4];   
                end
            end
        end
        end
        
        
        
        else if (ldCalc1) begin
        for (i=0; i<addr; i++) begin
            for (j=0; j<addr; j++) begin
                psub1[i][j] <= A11[i][j] + A22[i][j];
                psub2[i][j] <= B11[i][j] + B22[i][j];                
                qsub[i][j] <= A21[i][j] + A22[i][j];
                rsub[i][j] <= B12[i][j] - B22[i][j];
                ssub[i][j] <= B21[i][j] - B11[i][j];
                tsub[i][j] <= A11[i][j] + A12[i][j];
                usub1[i][j] <= A21[i][j] - A11[i][j];
                usub2[i][j] <= B11[i][j] + B12[i][j];
                vsub1[i][j] <= A12[i][j] - A22[i][j];
                vsub2[i][j] <= B21[i][j] + B22[i][j];
            end
         end
         end
    


        else if (ldCalc2) begin
        if (addr==4) begin
        for (i = 0; i < addr; i++) begin
            for (j = 0; j < addr; j++) begin
                tempSumP = 0;
                tempSumQ = 0;
                tempSumR = 0;
                tempSumS = 0;
                tempSumT = 0;
                tempSumU = 0;
                tempSumV = 0;
                for (int k = 0; k < addr; k++) begin
                    tempSumP += psub1[i][k] * psub2[k][j]; // P = (A11+A22) * (B11+B22)
                    tempSumQ += qsub[i][k] * B11[k][j]; // Q = (A21+A22) * B11
                    tempSumR += A11[i][k] * rsub[k][j]; // R = A11 * (B12-B22)
                    tempSumS += A22[i][k] * ssub[k][j]; // S = A22 * (B21-B11)
                    tempSumT += tsub[i][k] * B22[k][j]; // T = (A11+A12) * B22
                    tempSumU += usub1[i][k] * usub2[k][j]; // U = (A21-A11) * (B11+B12)
                    tempSumV += vsub1[i][k] * vsub2[k][j]; // V = (A12-A22) * (B21+B22)
                end
                P[i][j] <= tempSumP; // P[0][0]=x, P[0][1]=x, P[0][2]=x, ...
                Q[i][j] <= tempSumQ;
                R[i][j] <= tempSumR;
                S[i][j] <= tempSumS;
                T[i][j] <= tempSumT;
                U[i][j] <= tempSumU;
                V[i][j] <= tempSumV;
            end
        end
        end
        
        // RECURSIVE Strassen for P,Q,R,S,T,U,V
        else if (addr==8) begin
                slice4x4to2x2(psub1, psub2,
                            recursive_A11[0], recursive_A12[0], recursive_A21[0], recursive_A22[0],
                            recursive_B11[0], recursive_B12[0], recursive_B21[0], recursive_B22[0]); // P: A11, A12, A21, A22, B11, B12, B21, B22
            
                slice4x4to2x2(qsub, B11,
                              recursive_A11[1], recursive_A12[1], recursive_A21[1], recursive_A22[1],
                              recursive_B11[1], recursive_B12[1], recursive_B21[1], recursive_B22[1]); // Q: A11, A12, A21, A22, B11, B12, B21, B22
            
                slice4x4to2x2(A11, rsub,
                              recursive_A11[2], recursive_A12[2], recursive_A21[2], recursive_A22[2],
                              recursive_B11[2], recursive_B12[2], recursive_B21[2], recursive_B22[2]); // R: A11, A12, A21, A22, B11, B12, B21, B22
            
                slice4x4to2x2(A22, ssub,
                              recursive_A11[3], recursive_A12[3], recursive_A21[3], recursive_A22[3],
                              recursive_B11[3], recursive_B12[3], recursive_B21[3], recursive_B22[3]); // S: A11, A12, A21, A22, B11, B12, B21, B22
            
                slice4x4to2x2(tsub, B22,
                              recursive_A11[4], recursive_A12[4], recursive_A21[4], recursive_A22[4],
                              recursive_B11[4], recursive_B12[4], recursive_B21[4], recursive_B22[4]); // T: A11, A12, A21, A22, B11, B12, B21, B22
            
                slice4x4to2x2(usub1, usub2,
                              recursive_A11[5], recursive_A12[5], recursive_A21[5], recursive_A22[5],
                              recursive_B11[5], recursive_B12[5], recursive_B21[5], recursive_B22[5]); // U: A11, A12, A21, A22, B11, B12, B21, B22
            
                slice4x4to2x2(vsub1, vsub2,
                              recursive_A11[6], recursive_A12[6], recursive_A21[6], recursive_A22[6],
                              recursive_B11[6], recursive_B12[6], recursive_B21[6], recursive_B22[6]); // V: A11, A12, A21, A22, B11, B12, B21, B22      
        
            
                prepare_submatrices( 2, recursive_A11[0], recursive_A12[0], recursive_A21[0], recursive_A22[0],
                            recursive_B11[0], recursive_B12[0], recursive_B21[0], recursive_B22[0],
                                     recursive_psub1[0],recursive_psub2[0],recursive_qsub[0], recursive_rsub[0],
                                     recursive_ssub[0],recursive_tsub[0],recursive_usub1[0],recursive_usub2[0],
                                     recursive_vsub1[0],recursive_vsub2[0]
                                     ); // P
            
                prepare_submatrices( 2, recursive_A11[1], recursive_A12[1], recursive_A21[1], recursive_A22[1],
                              recursive_B11[1], recursive_B12[1], recursive_B21[1], recursive_B22[1],
                                     recursive_psub1[1],recursive_psub2[1],recursive_qsub[1], recursive_rsub[1],
                                     recursive_ssub[1],recursive_tsub[1],recursive_usub1[1],recursive_usub2[1],
                                     recursive_vsub1[1],recursive_vsub2[1]
                                     ); // Q            
        
                prepare_submatrices( 2, recursive_A11[2], recursive_A12[2], recursive_A21[2], recursive_A22[2],
                              recursive_B11[2], recursive_B12[2], recursive_B21[2], recursive_B22[2],
                                     recursive_psub1[2],recursive_psub2[2],recursive_qsub[2], recursive_rsub[2],
                                     recursive_ssub[2],recursive_tsub[2],recursive_usub1[2],recursive_usub2[2],
                                     recursive_vsub1[2],recursive_vsub2[2]
                                     ); // R        

                // S
                prepare_submatrices( 2, recursive_A11[3], recursive_A12[3], recursive_A21[3], recursive_A22[3],
                              recursive_B11[3], recursive_B12[3], recursive_B21[3], recursive_B22[3],
                                     recursive_psub1[3], recursive_psub2[3], recursive_qsub[3], recursive_rsub[3],
                                     recursive_ssub[3], recursive_tsub[3], recursive_usub1[3], recursive_usub2[3],
                                     recursive_vsub1[3], recursive_vsub2[3]
                );
                
                // T
                prepare_submatrices( 2, recursive_A11[4], recursive_A12[4], recursive_A21[4], recursive_A22[4],
                              recursive_B11[4], recursive_B12[4], recursive_B21[4], recursive_B22[4],
                                     recursive_psub1[4], recursive_psub2[4], recursive_qsub[4], recursive_rsub[4],
                                     recursive_ssub[4], recursive_tsub[4], recursive_usub1[4], recursive_usub2[4],
                                     recursive_vsub1[4], recursive_vsub2[4]
                );
                
                // U
                prepare_submatrices( 2, recursive_A11[5], recursive_A12[5], recursive_A21[5], recursive_A22[5],
                              recursive_B11[5], recursive_B12[5], recursive_B21[5], recursive_B22[5],
                                     recursive_psub1[5], recursive_psub2[5], recursive_qsub[5], recursive_rsub[5],
                                     recursive_ssub[5], recursive_tsub[5], recursive_usub1[5], recursive_usub2[5],
                                     recursive_vsub1[5], recursive_vsub2[5]
                );
                
                // V
                prepare_submatrices( 2, recursive_A11[6], recursive_A12[6], recursive_A21[6], recursive_A22[6],
                              recursive_B11[6], recursive_B12[6], recursive_B21[6], recursive_B22[6],
                                     recursive_psub1[6], recursive_psub2[6], recursive_qsub[6], recursive_rsub[6],
                                     recursive_ssub[6], recursive_tsub[6], recursive_usub1[6], recursive_usub2[6],
                                     recursive_vsub1[6], recursive_vsub2[6]
                );       
                    
                
                // ==========================
                // Compute Strassen Products
                // ==========================
                compute_strassen_products(2, 
                    // P set
                    recursive_psub1[0], recursive_psub2[0], recursive_qsub[0],
                    recursive_B11[0], recursive_A11[0], recursive_rsub[0], recursive_A22[0],
                    recursive_ssub[0], recursive_tsub[0], recursive_B22[0],
                    recursive_usub1[0], recursive_usub2[0], recursive_vsub1[0], recursive_vsub2[0],
                    recursive_P[0], recursive_Q[0], recursive_R[0], recursive_S[0],
                    recursive_T[0], recursive_U[0], recursive_V[0]
                );
                
                compute_strassen_products(2, 
                    // Q set
                    recursive_psub1[1], recursive_psub2[1], recursive_qsub[1],
                    recursive_B11[1], recursive_A11[1], recursive_rsub[1], recursive_A22[1],
                    recursive_ssub[1], recursive_tsub[1], recursive_B22[1],
                    recursive_usub1[1], recursive_usub2[1], recursive_vsub1[1], recursive_vsub2[1],
                    recursive_P[1], recursive_Q[1], recursive_R[1], recursive_S[1],
                    recursive_T[1], recursive_U[1], recursive_V[1]
                );
                
                compute_strassen_products(2, 
                    // R set
                    recursive_psub1[2], recursive_psub2[2], recursive_qsub[2],
                    recursive_B11[2], recursive_A11[2], recursive_rsub[2], recursive_A22[2],
                    recursive_ssub[2], recursive_tsub[2], recursive_B22[2],
                    recursive_usub1[2], recursive_usub2[2], recursive_vsub1[2], recursive_vsub2[2],
                    recursive_P[2], recursive_Q[2], recursive_R[2], recursive_S[2],
                    recursive_T[2], recursive_U[2], recursive_V[2]
                );
                
                compute_strassen_products(2, 
                    // S set
                    recursive_psub1[3], recursive_psub2[3], recursive_qsub[3],
                    recursive_B11[3], recursive_A11[3], recursive_rsub[3], recursive_A22[3],
                    recursive_ssub[3], recursive_tsub[3], recursive_B22[3],
                    recursive_usub1[3], recursive_usub2[3], recursive_vsub1[3], recursive_vsub2[3],
                    recursive_P[3], recursive_Q[3], recursive_R[3], recursive_S[3],
                    recursive_T[3], recursive_U[3], recursive_V[3]
                );
                
                compute_strassen_products(2, 
                    // T set
                    recursive_psub1[4], recursive_psub2[4], recursive_qsub[4],
                    recursive_B11[4], recursive_A11[4], recursive_rsub[4], recursive_A22[4],
                    recursive_ssub[4], recursive_tsub[4], recursive_B22[4],
                    recursive_usub1[4], recursive_usub2[4], recursive_vsub1[4], recursive_vsub2[4],
                    recursive_P[4], recursive_Q[4], recursive_R[4], recursive_S[4],
                    recursive_T[4], recursive_U[4], recursive_V[4]
                );
                
                compute_strassen_products(2, 
                    // U set
                    recursive_psub1[5], recursive_psub2[5], recursive_qsub[5],
                    recursive_B11[5], recursive_A11[5], recursive_rsub[5], recursive_A22[5],
                    recursive_ssub[5], recursive_tsub[5], recursive_B22[5],
                    recursive_usub1[5], recursive_usub2[5], recursive_vsub1[5], recursive_vsub2[5],
                    recursive_P[5], recursive_Q[5], recursive_R[5], recursive_S[5],
                    recursive_T[5], recursive_U[5], recursive_V[5]
                );
                
                compute_strassen_products(2, 
                    // V set
                    recursive_psub1[6], recursive_psub2[6], recursive_qsub[6],
                    recursive_B11[6], recursive_A11[6], recursive_rsub[6], recursive_A22[6],
                    recursive_ssub[6], recursive_tsub[6], recursive_B22[6],
                    recursive_usub1[6], recursive_usub2[6], recursive_vsub1[6], recursive_vsub2[6],
                    recursive_P[6], recursive_Q[6], recursive_R[6], recursive_S[6],
                    recursive_T[6], recursive_U[6], recursive_V[6]
                );
                
                
                 //P
                 combine_strassen_products(2,recursive_P[0],recursive_Q[0],recursive_R[0],recursive_S[0],
                                          recursive_T[0],recursive_U[0],recursive_V[0],
                                          P); 
                 //Q
                 combine_strassen_products(2,recursive_P[1],recursive_Q[1],recursive_R[1],recursive_S[1],
                                          recursive_T[1],recursive_U[1],recursive_V[1],
                                          Q);
                 //R
                 combine_strassen_products(2, recursive_P[2], recursive_Q[2], recursive_R[2], recursive_S[2],
                          recursive_T[2], recursive_U[2], recursive_V[2],
                          R);
                   
                 //S
                 combine_strassen_products(2, recursive_P[3], recursive_Q[3], recursive_R[3], recursive_S[3],
                          recursive_T[3], recursive_U[3], recursive_V[3],
                          S);
                 //T
                 combine_strassen_products(2, recursive_P[4], recursive_Q[4], recursive_R[4], recursive_S[4],
                          recursive_T[4], recursive_U[4], recursive_V[4],
                          T);
                 //U
                 combine_strassen_products(2, recursive_P[5], recursive_Q[5], recursive_R[5], recursive_S[5],
                          recursive_T[5], recursive_U[5], recursive_V[5],
                          U);
                 //V
                 combine_strassen_products(2, recursive_P[6], recursive_Q[6], recursive_R[6], recursive_S[6],
                          recursive_T[6], recursive_U[6], recursive_V[6],
                          V);
         
        end
        
        
        end
        
        
        
        else if (ldComb1) begin
        for (i=0; i<8; i++) begin
            for (j=0; j<8; j++) begin
                C11[i][j] <= P[i][j]+S[i][j]-T[i][j]+V[i][j]; // C11 = P+S-T+V
                C12[i][j] <= R[i][j]+T[i][j]; // C12 = R+T
                C21[i][j] <= Q[i][j]+S[i][j]; // C21 = Q+S
                C22[i][j] <= P[i][j]+R[i][j]-Q[i][j]+U[i][j]; // C22 = P+R-Q+U
            end
        end
        end
    
        
        
        else if (ldComb2) begin
        if (addr == 4) begin
            for (i = 0; i < 2; i++) begin
                for (j = 0; j < 2; j++) begin
                    // Top-left 2x2
                    dataOutC[i][j] <= C11[i][j];           // Rows 0-1, Cols 0-1
                    // Top-right 2x2
                    dataOutC[i][j + 2] <= C12[i][j];       // Rows 0-1, Cols 2-3
                    // Bottom-left 2x2
                    dataOutC[i + 2][j] <= C21[i][j];       // Rows 2-3, Cols 0-1
                    // Bottom-right 2x2
                    dataOutC[i + 2][j + 2] <= C22[i][j];   // Rows 2-3, Cols 2-3 
                end
            end
        end

        else if (addr == 8) begin
            for (i = 0; i < 4; i++) begin
                for (j = 0; j < 4; j++) begin
                    // Top-left 4x4
                    dataOutC[i][j] <= C11[i][j];           // Rows 0-3, Cols 0-3
                    // Top-right 4x4
                    dataOutC[i][j + 4] <= C12[i][j];       // Rows 0-3, Cols 4-7
                    // Bottom-left 4x4
                    dataOutC[i + 4][j] <= C21[i][j];       // Rows 4-7, Cols 0-3
                    // Bottom-right 4x4
                    dataOutC[i + 4][j + 4] <= C22[i][j];   // Rows 4-7, Cols 4-7
                end
            end
        end  
        end      
    end
    
    
endmodule


module topStrassen (
    input clk, start, reset,
    input [3:0] mode,
    output logic done,
    output logic [3:0] stateMM,
    output logic [11:0] memC_0, memC_1, memC_2, memC_3, memC_4, memC_5, memC_6, memC_7,
                    memC_8, memC_9, memC_10, memC_11, memC_12, memC_13, memC_14, memC_15,
                    memC_16, memC_17, memC_18, memC_19, memC_20, memC_21, memC_22, memC_23,
                    memC_24, memC_25, memC_26, memC_27, memC_28, memC_29, memC_30, memC_31,
                    memC_32, memC_33, memC_34, memC_35, memC_36, memC_37, memC_38, memC_39,
                    memC_40, memC_41, memC_42, memC_43, memC_44, memC_45, memC_46, memC_47,
                    memC_48, memC_49, memC_50, memC_51, memC_52, memC_53, memC_54, memC_55,
                    memC_56, memC_57, memC_58, memC_59, memC_60, memC_61, memC_62, memC_63,
    output logic we_tb, ldmemAB_tb, ldBF_tb, ldComb2_tb, ldSlice_tb, ldCalc1_tb, ldCalc2_tb, ldComb1_tb, clrAll_tb,
    output logic [3:0] addr_tb                
    );
    
    
    wire we, ldmemAB;
    wire [3:0] addr;
    wire [3:0] dataInA [0:7][0:7];      
    wire [3:0] dataInB [0:7][0:7];
    wire [11:0] dataOutC [0:7][0:7];    
    wire ldBF, ldComb2, ldSlice, ldCalc1, ldCalc2, ldComb1, clrAll;
    
    
    StrassenMM_DU strassenDU1(
        .clk(clk),
        .addr(addr),
        .dataInA(dataInA),      
        .dataInB(dataInB),
        .dataOutC(dataOutC),
        .ldBF(ldBF), .ldComb2(ldComb2), .ldSlice(ldSlice), .ldCalc1(ldCalc1), .ldCalc2(ldCalc2), .ldComb1(ldComb1), .clrAll(clrAll) 
    );
    
    StrassenMM_CU strassenCU1(
        .clk(clk),
        .start(start), 
        .reset(reset),              
        .mode(mode),       
        .done(done), 
        .we(we), 
        .addr(addr),
        .stateMM(stateMM),
        .ldmemAB(ldmemAB),       
        .ldBF(ldBF), .ldComb2(ldComb2), .ldSlice(ldSlice), .ldCalc1(ldCalc1), .ldCalc2(ldCalc2), .ldComb1(ldComb1), 
        .clrAll(clrAll)
     );
    
    memory bigmem1(
        .clk(clk),
        .we(we), 
        .done(done),
        .ldmemAB(ldmemAB),
        .addr(addr),
        .dataInC(dataOutC),  
        .dataInA(dataInA),      
        .dataInB(dataInB)
     );
     
     // unpack 2D memC to single element
    assign memC_0  = bigmem1.memC[0][0];
    assign memC_1  = bigmem1.memC[0][1];
    assign memC_2  = bigmem1.memC[0][2];
    assign memC_3  = bigmem1.memC[0][3];
    assign memC_4  = bigmem1.memC[0][4];
    assign memC_5  = bigmem1.memC[0][5];
    assign memC_6  = bigmem1.memC[0][6];
    assign memC_7  = bigmem1.memC[0][7];
    
    assign memC_8  = bigmem1.memC[1][0];
    assign memC_9  = bigmem1.memC[1][1];
    assign memC_10 = bigmem1.memC[1][2];
    assign memC_11 = bigmem1.memC[1][3];
    assign memC_12 = bigmem1.memC[1][4];
    assign memC_13 = bigmem1.memC[1][5];
    assign memC_14 = bigmem1.memC[1][6];
    assign memC_15 = bigmem1.memC[1][7];
    
    assign memC_16 = bigmem1.memC[2][0];
    assign memC_17 = bigmem1.memC[2][1];
    assign memC_18 = bigmem1.memC[2][2];
    assign memC_19 = bigmem1.memC[2][3];
    assign memC_20 = bigmem1.memC[2][4];
    assign memC_21 = bigmem1.memC[2][5];
    assign memC_22 = bigmem1.memC[2][6];
    assign memC_23 = bigmem1.memC[2][7];
    
    assign memC_24 = bigmem1.memC[3][0];
    assign memC_25 = bigmem1.memC[3][1];
    assign memC_26 = bigmem1.memC[3][2];
    assign memC_27 = bigmem1.memC[3][3];
    assign memC_28 = bigmem1.memC[3][4];
    assign memC_29 = bigmem1.memC[3][5];
    assign memC_30 = bigmem1.memC[3][6];
    assign memC_31 = bigmem1.memC[3][7];
    
    assign memC_32 = bigmem1.memC[4][0];
    assign memC_33 = bigmem1.memC[4][1];
    assign memC_34 = bigmem1.memC[4][2];
    assign memC_35 = bigmem1.memC[4][3];
    assign memC_36 = bigmem1.memC[4][4];
    assign memC_37 = bigmem1.memC[4][5];
    assign memC_38 = bigmem1.memC[4][6];
    assign memC_39 = bigmem1.memC[4][7];
    
    assign memC_40 = bigmem1.memC[5][0];
    assign memC_41 = bigmem1.memC[5][1];
    assign memC_42 = bigmem1.memC[5][2];
    assign memC_43 = bigmem1.memC[5][3];
    assign memC_44 = bigmem1.memC[5][4];
    assign memC_45 = bigmem1.memC[5][5];
    assign memC_46 = bigmem1.memC[5][6];
    assign memC_47 = bigmem1.memC[5][7];
    
    assign memC_48 = bigmem1.memC[6][0];
    assign memC_49 = bigmem1.memC[6][1];
    assign memC_50 = bigmem1.memC[6][2];
    assign memC_51 = bigmem1.memC[6][3];
    assign memC_52 = bigmem1.memC[6][4];
    assign memC_53 = bigmem1.memC[6][5];
    assign memC_54 = bigmem1.memC[6][6];
    assign memC_55 = bigmem1.memC[6][7];
    
    assign memC_56 = bigmem1.memC[7][0];
    assign memC_57 = bigmem1.memC[7][1];
    assign memC_58 = bigmem1.memC[7][2];
    assign memC_59 = bigmem1.memC[7][3];
    assign memC_60 = bigmem1.memC[7][4];
    assign memC_61 = bigmem1.memC[7][5];
    assign memC_62 = bigmem1.memC[7][6];
    assign memC_63 = bigmem1.memC[7][7];
    
     // trace the control signal on timing waveform
     assign we_tb = strassenCU1.we ; 
     assign ldmemAB_tb = strassenCU1.ldmemAB; 
     assign ldBF_tb = strassenCU1.ldBF; 
     assign ldComb2_tb = strassenCU1.ldComb2; 
     assign ldSlice_tb = strassenCU1.ldSlice; 
     assign ldCalc1_tb = strassenCU1.ldCalc1; 
     assign ldCalc2_tb = strassenCU1.ldCalc2; 
     assign ldComb1_tb = strassenCU1.ldComb1; 
     assign clrAll_tb = strassenCU1.clrAll;
     assign addr_tb = strassenCU1.addr;     
     
endmodule