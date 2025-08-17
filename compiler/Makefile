# Define o compilador C++ a ser usado
CXX = g++

# Define as flags de compilação:
# -std=c++17: Usa o padrão moderno do C++
# -Wall: Mostra todos os avisos (boa prática)
# -g: Inclui informações de debug no executável
CXXFLAGS = -std=c++17 -Wall -g

# Define o nome do arquivo fonte
SRCS = compiler.cpp

# Define o nome do arquivo executável de saída
TARGET = compiler

# Regra padrão: é executada quando você digita "make"
all: $(TARGET)

# Regra para criar o executável:
# Compila o arquivo fonte ($(SRCS)) e gera o executável ($(TARGET))
$(TARGET): $(SRCS)
	$(CXX) $(CXXFLAGS) $(SRCS) -o $(TARGET)
	@echo "Compilador '$(TARGET)' criado com sucesso."

# Regra "clean": remove os arquivos gerados para limpar a pasta
clean:
	rm -f $(TARGET)
	@echo "Arquivos compilados removidos."

# Declara que 'all' e 'clean' não são nomes de arquivos
.PHONY: all clean