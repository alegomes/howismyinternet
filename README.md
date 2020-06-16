# HowIsMyInternet?!?

Cansado de brigar com meu provedor de internet em relação à qualidade do serviço prestado, resolvi fazer esse script para monitorar alguns parâmetros de qualidade da minha conexão pra montar um histórico de dados com os quais pudesse comprovar os motivos de minha instatisfação.

# Dependências

Um dos parâmetros coletados pelo script é a velocidade da sua conexão. Para fazer isso, ele usa a biblioteca `speedtest`, que precisará ser previamente instalada em seu ambiente.

Basta seguir as instruções em https://github.com/sivel/speedtest-cli

# A Ser Melhorado

Além de imprimir o resultado na tela, o script também salva um arquivo de log em formato CSV. Eu escolhi salvá-lo no diretório `/var/log` do sistema operacional e acabei deixando isso fixo dentro do script. Como consequência, para o script ter as devidas permissões de escrever nesse diretório, você terá que executá-lo com privilégios de superusuário, i.e. `sudo`. Ou você pode também editar o próprio script trocando o diretório `/var/log` para outro qualquer de sua preferência.

# Running

É um script Bash bem simples feito e testado em um MacOS Catalina. 

Você pode executá-lo com 

`$ bash howismyinternet.sh`

ou

```
$ chmod a+x howismyinternet.sh
$ ./howismyinternet.sh
```

# Disclaimer

* O script foi criado para fins pessoais
* Logo, trata-se do mínimo necessário para atender às minhas necessidades imediatas
* Não estranhe (e nem reclame), portanto, com parâmetros hardcodeds :-P
* Pull requests são bem vindos :-)