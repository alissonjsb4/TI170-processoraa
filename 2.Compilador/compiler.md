# Documentação: Compilador de Arquivos Assembly para Binário

## **Descrição Geral**  
Este programa é um compilador simples que converte um arquivo de código assembly (`file.asm`) em um arquivo binário (`file.bin`). Ele reconhece um conjunto básico de instruções (mnemonics) e seus respectivos códigos de operação e argumentos.

---

## **Instruções Suportadas**  
A tabela abaixo mostra os mnemonics reconhecidos pelo compilador:  

| Mnemonic | Opcode   | Nº de Argumentos |
|----------|----------|------------------|
| INC      | 00000001 | 1                |
| DEC      | 00000010 | 1                |
| NOT      | 00000011 | 1                |
| JMP      | 00000100 | 1                |
| ADD      | 00010000 | 2                |
| SUB      | 00100000 | 2                |
| MUL      | 00110000 | 2                |
| DIV      | 01000000 | 2                |
| MOD      | 01010000 | 2                |
| AND      | 01100000 | 2                |
| OR       | 01110000 | 2                |
| XOR      | 10000000 | 2                |
| NAND     | 10010000 | 2                |
| NOR      | 10100000 | 2                |
| XNOR     | 10110000 | 2                |
| COMP     | 11000000 | 2                |


---

## **Funcionamento**  

1. **Entrada:** O programa recebe dois arquivos como argumentos:  
   - Arquivo de entrada (`file.asm`): Contém o código assembly a ser compilado.  
   - Arquivo de saída (`file.bin`): Arquivo binário gerado após a compilação.

2. **Processamento:**  
   - Remove comentários (qualquer texto após `;`).  
   - Remove espaços em branco (A D D se torna ADD).
   - Verifica se o comando é reconhecido.  
   - Verifica se há o número correto de argumentos por comando.
   - Valida os argumentos quanto ao formato binário e tamanho esperado (8 bits). 
   - Completa com zeros argumentos com menos de 8 bits (1 se torna 00000001).
   - Escreve o código de operação e argumentos no arquivo binário. 
   - O binário gerado terá no mínimo 128 linhas, para ser aceito no processador.

3. **Saída:** O arquivo binário gerado contém a sequência de opcodes e argumentos correspondentes às instruções no arquivo assembly.

---

## **Erros Possíveis**  

1. **Erro de Uso:**  
   - **Mensagem:** `Usage: ./compiler file.asm file.bin`  
   - **Causa:** Número incorreto de argumentos passados ao executar o programa.

2. **Erro de Abertura de Arquivo:**  
   - **Mensagem:** `Cannot open <filename>`  
   - **Causa:** Arquivo não encontrado ou sem permissões de leitura/escrita.

3. **Comando Desconhecido:**  
   - **Mensagem:** `Command <cmd> is undefined`  
   - **Causa:** Comando não reconhecido pelo compilador.

4. **Fim de Arquivo Prematuro:**  
   - **Mensagem:** `EOF reached before expected arguments`  
   - **Causa:** Número de argumentos fornecidos é menor que o esperado para o comando atual.

5. **Argumento Inválido:**  
   - **Mensagem:** `Invalid argument <arg> for command <cmd>`  
   - **Causa:** Argumento não está no formato binário ou tem tamanho diferente de 8 bits.

---
