# Dependências e licenças

## Componentes usados

- Windows 11 x64 e APIs nativas DXGI / Direct3D 12.
- Windows SDK 10.0.26100 e MSVC Build Tools para compilar C++.
- `fxc` já presente no ambiente para compilar HLSL Shader Model 5.1.
- Driver NVIDIA instalado, `nvidia-smi` e `nvcuda.dll` para as consultas/enumeração CUDA da Fase 1. O diagnóstico não detectou CUDA Toolkit/`nvcc` instalado.
- PowerShell e CIM/WMI para coleta e organização.

Essas ferramentas não foram instaladas por esta tarefa. O protótipo usa interfaces do Windows e driver já disponíveis; não há pacote de terceiros incorporado ao código-fonte organizado.

## Situação de licença

Não foi encontrado `LICENSE`, `NOTICE` ou `COPYING` nos diretórios das fases. A licença do próprio projeto NEXO DUAL GPU ainda não foi definida. Os fontes não devem ser publicados nem redistribuídos até o proprietário decidir a licença e revisar as obrigações aplicáveis.

Windows SDK, MSVC, `fxc`, NVIDIA driver e suas ferramentas são componentes de terceiros sujeitos aos termos de seus fornecedores. Não os redistribuir junto com o projeto sem conferir os termos. Os `.exe` e `.cso` locais são artefatos gerados e permanecem ignorados pelo Git.

## Reprodutibilidade

As versões e comandos registrados nos relatórios de Fase 2 e 3 são a referência atual. Antes de reprodução externa, registrar as versões exatas de SDK, compilador, driver, GPU e opções do script de build.
