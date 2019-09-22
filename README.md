# Square-Wave-Generator
## Describtion
This school project is codded in Assembly created on K65 MCU. 
I create a square wave generator with terminal interface to control the frequency of the signal.
Using the "bit banging" method on a gpio port generates the square wave with certain frequency.
However, in order to create relatively precise timing, a routine to delay the whole system is needed, 
which means understanding of the frequency of the MCU and the period of each assembly comand is needed.
In order to improve the performance of the function generator, I can use the peripheral clock on the MCU 
to generator signals with more accurate frequency.
