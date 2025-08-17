//======================================================================================
// 8-bit CPU Assembler
//
// Author: Alisson Jaime Sales Barros
// Course: Microprocessors - Federal University of Ceará (UFC)
//
// Description:
// This is a simple command-line assembler written in C++. It translates a custom
// assembly language file (.asm) into a binary machine code file (.bin) that can be
// executed by the custom 8-bit processor. The assembler parses mnemonics,
// validates arguments, and outputs corresponding opcodes and operands.
//
//======================================================================================

#include <iostream>
#include <fstream>
#include <string>
#include <algorithm>
#include <map>
#include <vector>

#define WORD_SIZE 8
#define MIN_BINARY_LINES 128

// Use a more descriptive alias for the standard namespace
using namespace std;

// Holds information about each instruction in the ISA
struct InstructionInfo {
    string opcode;
    int num_arguments;
};

// Map of mnemonics to their corresponding opcode and argument count
const map<string, InstructionInfo> mnemonics = {
    { "INC",  {"00000001", 1} }, // Increment
    { "DEC",  {"00000010", 1} }, // Decrement
    { "NOT",  {"00000011", 1} }, // Bitwise NOT
    { "JMP",  {"00000100", 1} }, // Unconditional Jump
    { "ADD",  {"00010000", 2} }, // Addition
    { "SUB",  {"00100000", 2} }, // Subtraction
    { "MUL",  {"00110000", 2} }, // Multiplication
    { "DIV",  {"01000000", 2} }, // Division
    { "MOD",  {"01010000", 2} }, // Modulo
    { "AND",  {"01100000", 2} }, // Bitwise AND
    { "OR" ,  {"01110000", 2} }, // Bitwise OR
    { "XOR",  {"10000000", 2} }, // Bitwise XOR
    { "NAND", {"10010000", 2} }, // Bitwise NAND
    { "NOR",  {"10100000", 2} }, // Bitwise NOR
    { "XNOR", {"10110000", 2} }, // Bitwise XNOR
    { "COMP", {"11000000", 2} }  // Compare
};

// Removes comments (anything after a ';') from a line
void removeComments(string &line) {
    size_t comment_pos = line.find(';');
    if (comment_pos != string::npos) {
        line.erase(comment_pos);
    }
}

// Removes all whitespace characters from a string
void removeSpaces(string &line) {
    line.erase(remove(line.begin(), line.end(), ' '), line.end());
    line.erase(remove(line.begin(), line.end(), '\t'), line.end());
}

// Checks if a string contains only '0's and '1's
bool isBinary(const string& str) {
    return !str.empty() && str.find_first_not_of("01") == string::npos;
}

// Checks if a string is a valid mnemonic
bool isCommand(const string& str) {
    return mnemonics.count(str) > 0;
}

// Pads a binary string with leading zeros to match WORD_SIZE
string padArgument(const string& binary) {
    if (binary.length() >= WORD_SIZE) {
        return binary;
    }
    size_t missingZeros = WORD_SIZE - binary.length();
    return string(missingZeros, '0') + binary;
}

int main(int argc, char** argv) {
    if (argc != 3) {
        cerr << "Usage: " << argv[0] << " <input_file.asm> <output_file.bin>" << endl;
        return 1;
    }
    
    ifstream inputFile(argv[1]);
    if (!inputFile.is_open()) {
        cerr << "Error: Cannot open input file '" << argv[1] << "'" << endl;
        return 2;
    }

    ofstream outputFile(argv[2]);
    if (!outputFile.is_open()) {
        cerr << "Error: Cannot open output file '" << argv[2] << "'" << endl;
        inputFile.close();
        return 2;
    }

    string lineBuffer;
    int lineCounter = 0;
    vector<string> binaryLines;

    // Main loop: Parse the assembly file line by line
    while (getline(inputFile, lineBuffer)) {
        lineCounter++;
        removeComments(lineBuffer);
        removeSpaces(lineBuffer);

        if (lineBuffer.empty()) {
            continue;
        }

        if (!isCommand(lineBuffer)) {
            cerr << "Error [Line " << lineCounter << "]: Unknown command '" << lineBuffer << "'." << endl;
            inputFile.close();
            outputFile.close();
            return 3;
        }

        const auto& instruction = mnemonics.at(lineBuffer);
        binaryLines.push_back(instruction.opcode);

        // Inner loop: Read the expected number of arguments for the command
        for (int i = 0; i < instruction.num_arguments; ++i) {
            string argBuffer;
            bool argFound = false;
            while(getline(inputFile, argBuffer)) {
                lineCounter++;
                removeComments(argBuffer);
                removeSpaces(argBuffer);
                if (!argBuffer.empty()) {
                    argFound = true;
                    break;
                }
            }

            if (!argFound) {
                cerr << "Error: End of file reached while expecting an argument for command '" << lineBuffer << "'." << endl;
                return 4;
            }

            if (!isBinary(argBuffer) || argBuffer.length() > WORD_SIZE) {
                cerr << "Error [Line " << lineCounter << "]: Invalid argument '" << argBuffer << "' for command '" << lineBuffer << "'." << endl;
                cerr << "Expected an " << WORD_SIZE << "-bit binary string." << endl;
                return 5;
            }

            binaryLines.push_back(padArgument(argBuffer));
        }
    }

    // Write all processed lines to the output file
    for(const auto& binLine : binaryLines) {
        outputFile << binLine << endl;
    }

    // Pad the binary file with zeros to meet the minimum line requirement for the processor's memory
    for (size_t i = binaryLines.size(); i < MIN_BINARY_LINES; ++i) {
        outputFile << string(WORD_SIZE, '0') << endl;
    }

    cout << "Compilation successful. " << binaryLines.size() << " lines of code generated." << endl;
    cout << "Output written to '" << argv[2] << "'" << endl;

    inputFile.close();
    outputFile.close();
    return 0;
}
