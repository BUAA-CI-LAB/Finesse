`include "../define/params.svh"
/*
    File contains: parameters define
    Author: Tianao Dai
*/

/* =============================================================================== 
                            Pre-defined(Partial Hardware Setup)
   =============================================================================== */

/* Top-layer port bitwidth define */
`define PORTW       32
`define PORTWLOG2   5
`define PORTAW      `PORTWLOG2 + `RFSZLOG2

/* Initial instruction address */
`define INITADDR    0

/* Termination instructions */
`define HALT_INSTR  0

/*  Function ID bit width */
`define FUNCIDW     6

/* Instruction set define */
`define OP_NEG      1
`define OP_DBL      2
`define OP_TPL      3
`define OP_ADD      4
`define OP_SUB      5
`define OP_SQR      6
`define OP_MUL      7
`define OP_CVT      8
`define OP_ICV      9
`define OP_INV      10

/* ALUs stages define */
`define ADDCTHRES   160

/* ALUs stages define */
// `MODMUL is 3x(mul cycles)+3
// `MODLINS = add_delay - 4
// `MODMUL = mul_delay - 4
`define MODLINS     4
`define MODMUL      34
`define MODINV      (`WORDSZ*2+2)

/* Core number */
// if CORE_NUM = 1 then the chip_sel is invalid and the CORELOG2 = 1(cannot be 0)
`define CORE_NUM    1
`define CORELOG2    1

/* =============================================================================== 
                                    Other define
   =============================================================================== */

/* Platform select define: 0-FPGA 1-ASIC */
`define ASIC_MODE   0

/* TEST/NONETEST MODE define */
`define TEST_MODE   0

/* CRLF - (`IMSLICEW/4+2) : LF - (`IMSLICEW/4+1) */
`define HEXLEN      (`IMSLICEW/4+1)

/* =============================================================================== 
                                    TEMP define
   =============================================================================== */

