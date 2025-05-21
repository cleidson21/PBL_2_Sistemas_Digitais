C_FILE = main
S_FILE = matrix_io
TARGET = main

all: $(S_FILE).o $(C_FILE).o $(TARGET)
	@echo "Compilation complete"

$(S_FILE).o: $(S_FILE).s
	as -o $(S_FILE).o $(S_FILE).s

$(C_FILE).o: $(C_FILE).c interface.h
	gcc -c -o $(C_FILE).o $(C_FILE).c

$(TARGET): $(S_FILE).o $(C_FILE).o
	gcc -o $(TARGET) $(S_FILE).o $(C_FILE).o

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f *.o $(TARGET)

debug: $(TARGET)
	gdb $(TARGET)
