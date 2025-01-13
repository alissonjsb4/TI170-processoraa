module output_ports (
    input clock,                // Sinal de clock
    input reset,                // Sinal de reset ativo baixo
    input [7:0] address,        // Endereço de memória
    input [7:0] data_in,        // Dados de entrada para a porta de saída
    input write,                // Sinal de escrita
    output reg [7:0] port_out_00, // Porta de saída 00
    output reg [7:0] port_out_01  // Porta de saída 01
);

    //-- port_out_00 (endereço E0)
    always @ (posedge clock or negedge reset)
    begin
        if (!reset)
            port_out_00 <= 8'h00;  // Inicializa com valor 0 no reset
        else if ((address == 8'hE0) && write) 
            port_out_00 <= data_in; // Atualiza o valor da porta de saída quando o endereço é E0
    end

    //-- port_out_01 (endereço E1)
    always @ (posedge clock or negedge reset)
    begin
        if (!reset)
            port_out_01 <= 8'h00;  // Inicializa com valor 0 no reset
        else if ((address == 8'hE1) && write) 
            port_out_01 <= data_in; // Atualiza o valor da porta de saída quando o endereço é E1
    end

    // Continuar com o restante dos modelos de portas de saída...

endmodule
