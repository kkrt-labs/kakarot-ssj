<p align="center">
    <img src="docs/img/kakarot_github_banner.png" height="200">
</p>

<div align="center">
<br />

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/sayajin-labs/kakarot-ssj/test.yml?branch=main)
![GitHub](https://img.shields.io/github/license/sayajin-labs/kakarot-ssj?style=flat-square&logo=github)
![GitHub contributors](https://img.shields.io/github/contributors/sayajin-labs/kakarot-ssj?logo=github&style=flat-square)
![GitHub top language](https://img.shields.io/github/languages/top/sayajin-labs/kakarot-ssj?style=flat-square)
[![Telegram](https://img.shields.io/badge/telegram-Kakarot-yellow.svg?logo=telegram)](https://t.me/KakarotZkEvm)
![Contributions welcome](https://img.shields.io/badge/contributions-welcome-orange.svg)
[![Read FAQ](https://img.shields.io/badge/Ask%20Question-Read%20FAQ-000000)](https://www.newton.so/view?tags=kakarot)
![GitHub Repo stars](https://img.shields.io/github/stars/sayajin-labs/kakarot-ssj?style=social)
[![Twitter Follow](https://img.shields.io/twitter/follow/KakarotZkEvm?style=social)](https://twitter.com/KakarotZkEvm)

</div>

<details>
<summary>Table of Contents</summary>

- [About](#about)
- [Getting Started](#getting-started)
  - [Installation](#installation)
- [Usage](#usage)
  - [Build](#build)
  - [Test](#test)
  - [Format](#format)
- [Roadmap](#roadmap)
- [Support](#support)
- [Project assistance](#project-assistance)
- [Contributing](#contributing)
- [Authors \& contributors](#authors--contributors)
- [Security](#security)
- [License](#license)
- [Acknowledgements](#acknowledgements)
- [Contributors ✨](#contributors-)

</details>

---

## About

Kakarot is an (zk)-Ethereum Virtual Machine implementation written in Cairo.
Kakarot is Ethereum compatible, i.e. all existing smart contracts, developer
tools and wallets work out-of-the-box on Kakarot. It's been open source from day
one. Soon available on Starknet L2 and L3.

🚧 It is a work in progress, and it is not ready for production.

## Getting Started

This repository is a rewrite of
[the first version of Kakarot zkEVM](https://github.com/kkrt-labs/kakarot).

### Installation

- Install [Scarb](https://docs.swmansion.com/scarb). To make sure your version
  always matches the one used by Kakarot, you can install Scarb
  [via asdf](https://docs.swmansion.com/scarb/download#install-via-asdf).

- [Fork](https://docs.github.com/en/get-started/quickstart/fork-a-repo) the
  repository and clone your fork
  (`git clone https://github.com/<YOUR_USERNAME>/kakarot-ssj`)

- Run `make install` to install the git hooks.
- Add your environment variables to `.env` (see `.env.example` for an example).

## Usage

### Build

```bash
scarb build
```

### Test

```bash
scarb test
```

### Format

```bash
scarb fmt
```

## Roadmap

See the [open issues](https://github.com/sayajin-labs/kakarot-ssj/issues) for a
list of proposed features (and known issues).

- [Top Feature Requests](https://github.com/sayajin-labs/kakarot-ssj/issues?q=label%3Aenhancement+is%3Aopen+sort%3Areactions-%2B1-desc)
  (Add your votes using the 👍 reaction)
- [Top Bugs](https://github.com/sayajin-labs/kakarot-ssj/issues?q=is%3Aissue+is%3Aopen+label%3Abug+sort%3Areactions-%2B1-desc)
  (Add your votes using the 👍 reaction)
- [Newest Bugs](https://github.com/sayajin-labs/kakarot-ssj/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

## Support

Reach out to the maintainer at one of the following places:

- [GitHub Discussions](https://github.com/sayajin-labs/kakarot-ssj/discussions)
- [Telegram group](https://t.me/KakarotZkEvm)

## Project assistance

If you want to say **thank you** or/and support active development of Kakarot:

- Add a [GitHub Star](https://github.com/sayajin-labs/kakarot-ssj) to the
  project.
- Tweet about [Kakarot](https://twitter.com/KakarotZkEvm).
- Write interesting articles about the project on [Dev.to](https://dev.to/),
  [Medium](https://medium.com/), [Mirror](https://mirror.xyz/) or your personal
  blog.

Together, we can make Kakarot **better**!

## Contributing

First off, thanks for taking the time to contribute! Contributions are what make
the open-source community such an amazing place to learn, inspire, and create.
Any contribution you make will benefit everybody else and is **greatly
appreciated**.

Please read [our contribution guidelines](docs/CONTRIBUTING.md), and thank you
for being involved!

## Authors & contributors

For a full list of all authors and contributors, see
[the contributors page](https://github.com/sayajin-labs/kakarot-ssj/contributors).

## Security

Kakarot follows good practices of security, but 100% security cannot be assured.
Kakarot is provided **"as is"** without any **warranty**. Use at your own risk.

_For more information and to report security issues, please refer to our
[security documentation](docs/SECURITY.md)._

## License

This project is licensed under the **MIT license**.

See [LICENSE](LICENSE) for more information.

## Acknowledgements

## Contributors ✨

Thanks goes to these wonderful people
([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/abdelhamidbakhta"><img src="https://avatars.githubusercontent.com/u/45264458?v=4?s=100" width="100px;" alt="Abdel @ StarkWare "/><br /><sub><b>Abdel @ StarkWare </b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=abdelhamidbakhta" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/jobez"><img src="https://avatars.githubusercontent.com/u/615197?v=4?s=100" width="100px;" alt="johann bestowrous"/><br /><sub><b>johann bestowrous</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=jobez" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Eikix"><img src="https://avatars.githubusercontent.com/u/66871571?v=4?s=100" width="100px;" alt="Elias Tazartes"/><br /><sub><b>Elias Tazartes</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/pulls?q=is%3Apr+reviewed-by%3AEikix" title="Reviewed Pull Requests">👀</a> <a href="#tutorial-Eikix" title="Tutorials">✅</a> <a href="#talk-Eikix" title="Talks">📢</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/enitrat"><img src="https://avatars.githubusercontent.com/u/60658558?v=4?s=100" width="100px;" alt="Mathieu"/><br /><sub><b>Mathieu</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=enitrat" title="Code">💻</a> <a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=enitrat" title="Tests">⚠️</a> <a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=enitrat" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/khaeljy"><img src="https://avatars.githubusercontent.com/u/1810456?v=4?s=100" width="100px;" alt="khaeljy"/><br /><sub><b>khaeljy</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=khaeljy" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://www.linkedin.com/in/clementwalter/"><img src="https://avatars.githubusercontent.com/u/18620296?v=4?s=100" width="100px;" alt="Clément Walter"/><br /><sub><b>Clément Walter</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=ClementWalter" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/LucasLvy"><img src="https://avatars.githubusercontent.com/u/70894690?v=4?s=100" width="100px;" alt="Lucas @ StarkWare"/><br /><sub><b>Lucas @ StarkWare</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=LucasLvy" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/lambda-0x"><img src="https://avatars.githubusercontent.com/u/87354252?v=4?s=100" width="100px;" alt="lambda-0x"/><br /><sub><b>lambda-0x</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=lambda-0x" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/danilowhk"><img src="https://avatars.githubusercontent.com/u/12735159?v=4?s=100" width="100px;" alt="danilowhk"/><br /><sub><b>danilowhk</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=danilowhk" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://nodeguardians.io/character/98995858fd55"><img src="https://avatars.githubusercontent.com/u/122918260?v=4?s=100" width="100px;" alt="TAdev"/><br /><sub><b>TAdev</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=TAdev0" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Quentash"><img src="https://avatars.githubusercontent.com/u/100387965?v=4?s=100" width="100px;" alt="Quentash"/><br /><sub><b>Quentash</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=Quentash" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ftupas"><img src="https://avatars.githubusercontent.com/u/35031356?v=4?s=100" width="100px;" alt="ftupas"/><br /><sub><b>ftupas</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=ftupas" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://aniketpr01.github.io/"><img src="https://avatars.githubusercontent.com/u/46114123?v=4?s=100" width="100px;" alt="Aniket Prajapati"/><br /><sub><b>Aniket Prajapati</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=aniketpr01" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/dbejarano820"><img src="https://avatars.githubusercontent.com/u/58019353?v=4?s=100" width="100px;" alt="Daniel Bejarano"/><br /><sub><b>Daniel Bejarano</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=dbejarano820" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Noeljarillo"><img src="https://avatars.githubusercontent.com/u/77942794?v=4?s=100" width="100px;" alt="Noeljarillo"/><br /><sub><b>Noeljarillo</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=Noeljarillo" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/trbutler4"><img src="https://avatars.githubusercontent.com/u/58192340?v=4?s=100" width="100px;" alt="Thomas Butler"/><br /><sub><b>Thomas Butler</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=trbutler4" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/kariy"><img src="https://avatars.githubusercontent.com/u/26515232?v=4?s=100" width="100px;" alt="Ammar Arif"/><br /><sub><b>Ammar Arif</b></sub></a><br /><a href="https://github.com/sayajin-labs/kakarot-ssj/commits?author=kariy" title="Documentation">📖</a></td>
    </tr>
  </tbody>
  <tfoot>
    <tr>
      <td align="center" size="13px" colspan="7">
        <img src="https://raw.githubusercontent.com/all-contributors/all-contributors-cli/1b8533af435da9854653492b1327a23a4dbd0a10/assets/logo-small.svg">
          <a href="https://all-contributors.js.org/docs/en/bot/usage">Add your contributions</a>
        </img>
      </td>
    </tr>
  </tfoot>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the
[all-contributors](https://github.com/all-contributors/all-contributors)
specification. Contributions of any kind welcome!

<p align="center">
    <img src="docs/img/kakarot_github_banner_footer.png" height="200">
</p>
