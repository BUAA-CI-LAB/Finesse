`timescale 1ns / 1ps

module add6to3_1b(
    input i0,
    input i1,
    input i2,
    input i3,
    input i4,
    input i5,
    output o0,
    output o1,
    output o2
);
assign {o2, o1, o0} = i0 + i1 + i2 + i3 + i4 + i5;
// assign o0 = i0 ^ i1 ^ i2 ^ i3 ^ i4 ^ i5;
// assign o1 = i0&i1&~i2&~i3&~i4&~i5|i0&~i1&i2&~i3&~i4&~i5|~i0&i1&i2&~i3&~i4&~i5|i0&i1&i2&~i3&~i4&~i5|i0&~i1&~i2&i3&~i4&~i5|~i0&i1&~i2&i3&~i4&~i5|i0&i1&~i2&i3&~i4&~i5|~i0&~i1&i2&i3&~i4&~i5|i0&~i1&i2&i3&~i4&~i5|~i0&i1&i2&i3&~i4&~i5|i0&~i1&~i2&~i3&i4&~i5|~i0&i1&~i2&~i3&i4&~i5|i0&i1&~i2&~i3&i4&~i5|~i0&~i1&i2&~i3&i4&~i5|i0&~i1&i2&~i3&i4&~i5|~i0&i1&i2&~i3&i4&~i5|~i0&~i1&~i2&i3&i4&~i5|i0&~i1&~i2&i3&i4&~i5|~i0&i1&~i2&i3&i4&~i5|~i0&~i1&i2&i3&i4&~i5|i0&~i1&~i2&~i3&~i4&i5|~i0&i1&~i2&~i3&~i4&i5|i0&i1&~i2&~i3&~i4&i5|~i0&~i1&i2&~i3&~i4&i5|i0&~i1&i2&~i3&~i4&i5|~i0&i1&i2&~i3&~i4&i5|~i0&~i1&~i2&i3&~i4&i5|i0&~i1&~i2&i3&~i4&i5|~i0&i1&~i2&i3&~i4&i5|~i0&~i1&i2&i3&~i4&i5|~i0&~i1&~i2&~i3&i4&i5|i0&~i1&~i2&~i3&i4&i5|~i0&i1&~i2&~i3&i4&i5|~i0&~i1&i2&~i3&i4&i5|~i0&~i1&~i2&i3&i4&i5|i0&i1&i2&i3&i4&i5;
// assign o2 = i0&i1&i2&i3&~i4&~i5|i0&i1&i2&~i3&i4&~i5|i0&i1&~i2&i3&i4&~i5|i0&~i1&i2&i3&i4&~i5|~i0&i1&i2&i3&i4&~i5|i0&i1&i2&i3&i4&~i5|i0&i1&i2&~i3&~i4&i5|i0&i1&~i2&i3&~i4&i5|i0&~i1&i2&i3&~i4&i5|~i0&i1&i2&i3&~i4&i5|i0&i1&i2&i3&~i4&i5|i0&i1&~i2&~i3&i4&i5|i0&~i1&i2&~i3&i4&i5|~i0&i1&i2&~i3&i4&i5|i0&i1&i2&~i3&i4&i5|i0&~i1&~i2&i3&i4&i5|~i0&i1&~i2&i3&i4&i5|i0&i1&~i2&i3&i4&i5|~i0&~i1&i2&i3&i4&i5|i0&~i1&i2&i3&i4&i5|~i0&i1&i2&i3&i4&i5|i0&i1&i2&i3&i4&i5;
endmodule

/*
Carry Save Adder

RES = o0 + (o1 << 1) + (o2 << 2)
*/

module add6to3
#(parameter integer WIDTH = 1)
(
    input [WIDTH-1:0] i0,
    input [WIDTH-1:0] i1,
    input [WIDTH-1:0] i2,
    input [WIDTH-1:0] i3,
    input [WIDTH-1:0] i4,
    input [WIDTH-1:0] i5,
    output [WIDTH-1:0] o0,
    output [WIDTH-1:0] o1,
    output [WIDTH-1:0] o2
);
genvar i;
generate
  for (i = 0; i < WIDTH; i += 1) begin : gen_add6to3_1b
    add6to3_1b b(.i0(i0[i]), .i1(i1[i]), .i2(i2[i]), .i3(i3[i]), .i4(i4[i]), .i5(i5[i]),
                 .o0(o0[i]), .o1(o1[i]), .o2(o2[i]));
  end
endgenerate
endmodule
/*
s = ['i0', 'i1', 'i2', 'i3', 'i4', 'i5']
for i in range(64):
  c = bin(i).count('1')
  if not (c & 4):
    continue
  for j in range(6):
    if not (i & (1 << j)):
      print('~', end='')
    print(s[j], end='')
    if j != 5:
      print('&', end='')
    else:
      print('|', end='')
*/
