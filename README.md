# Biblioteca de Comunicação HPS–FPGA para Coprocessador Matricial

## Sumário

*Inserir Sumário aqui*

## Introdução

Este projeto implementa uma biblioteca em Assembly para estabelecer a comunicação entre o processador HPS (Hard Processor System) e um coprocessador matricial desenvolvido em Verilog e implementado no FPGA da placa DE1-SoC.

O objetivo é permitir que o HPS delegue operações com matrizes (como soma, subtração, multiplicação escalar, transposição, entre outras) para um hardware dedicado, otimizando o desempenho e reduzindo o tempo de execução dessas tarefas. A comunicação entre os dois lados é feita por meio de registradores mapeados em memória, acessíveis via instruções Assembly diretamente pelo HPS.

## 👥 Equipe

- **[Cleidson Ramos de Carvalho](https://github.com/cleidson21)**  
- **[Pedro Arthur Nery da Rocha Costa](https://github.com/pedroarthur2002)**  
- **[Uemerson Jesus](https://github.com/Uemersonjesus)**

## Requisitos do Problema

- O código da biblioteca deve ser escrito em linguagem Assembly
- A biblioteca deve conter as funções essenciais para que seja possível utilizar as operações matriciais implementadas no coprocessador
- A biblioteca deve seguir as recomendações descritas em: [https://github.com/MaJerle/c-code-style](https://github.com/MaJerle/c-code-style)

## Recursos Utilizados

### Quartus Prime

O **Quartus Prime** foi a principal ferramenta de desenvolvimento utilizada para síntese, compilação e implementação do projeto em Verilog HDL. As funções desempenhadas pelo software incluem:

- **Síntese e Análise de Recursos**: Tradução do código Verilog para circuitos lógicos, permitindo a avaliação de recursos da FPGA, como **LUTs** e **DSPs**.
- **Compilação e Geração de Bitstream**: Compilação do projeto e geração do arquivo necessário para programar a FPGA.
- **Gravação na FPGA**: Programação da FPGA utilizando a ferramenta **Programmer** e o cabo **USB-Blaster**.
- **Pinagem com Pin Planner**: Ferramenta para mapear sinais de entrada e saída do projeto aos pinos físicos da FPGA, como **LEDs**, **switches**, **botões** e **displays**.

### FPGA DE1-SoC

A **FPGA DE1-SoC** foi a plataforma utilizada para a implementação e testes do coprocessador. Essa placa combina um FPGA da Intel com diversos periféricos integrados, oferecendo uma solução robusta para sistemas embarcados e aplicações de hardware reconfigurável.

- **Dispositivo FPGA**: Cyclone® V SE 5CSEMA5F31C6N.
- **Memória Embarcada**: 4.450 Kbits e 6 blocos DSP de 18x18 bits.
- **Entradas e Saídas**: Utilização de 4 botões de pressão, 10 chaves deslizantes e 10 LEDs vermelhos de usuário.

Para mais informações técnicas, consulte o [Manual da Placa DE1-SoC (PDF)](https://drive.google.com/file/d/1dBaSfXi4GcrSZ0JlzRh5iixaWmq0go2j/view).

## Desenvolvimento

*Explicar o projeto de maneira detalhada nessa seção*

## Referências

- [Manual da Placa DE1-SoC (PDF)](https://drive.google.com/file/d/1dBaSfXi4GcrSZ0JlzRh5iixaWmq0go2j/view)
- [Manual do ARMv7-A](https://developer.arm.com/documentation/ddi0406/latest/)
- [Quartus Prime - Documentação Oficial](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/overview.html)
