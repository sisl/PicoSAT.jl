#all: @TARGETS@

analyze:
	clang --analyze $(CFLAGS) *.c *.h

picosat.o: picosat.c picosat.h
	$(CC) $(CFLAGS) -fPIC -c $<

libpicosat.a: picosat.o
	ar rc $@ picosat.o

libpicosat.so: picosat.o
	$(CC) $(CFLAGS) -O3 -shared -o $@ picosat.o #$(SONAME)

clean:
	rm -rf *.so *.o *.a

.PHONY: all clean
