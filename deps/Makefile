#all: @TARGETS@

analyze:
	clang --analyze $(CFLAGS) *.c *.h

picosat.o: picosat.c picosat.h
	$(CC) $(CFLAGS) -fPIC -c $<

libpicosat.a: picosat.o
	ar rc $@ picosat.o
	#ranlib $@

#SONAME=-Xlinker -soname -Xlinker libpicosat.so
libpicosat.so: picosat.o
	$(CC) $(CFLAGS) -shared -o $@ picosat.o #$(SONAME)

clean:
	rm -rf *.so *.o *.a

.PHONY: all clean
