FROM ubuntu:24.04

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential tools
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    git \
    curl \
    wget \
    unzip \
    # ACME cross-assembler for 6502
    acme \
    # VICE emulator (including petcat for BASIC conversion)
    vice \
    # Screenshot capture (headless)
    xvfb \
    imagemagick \
    xdotool \
    # Text editors
    vim \
    nano \
    # Utilities
    make \
    && rm -rf /var/lib/apt/lists/*

# Add screenshot capture script and input scripts
COPY scripts/c64-screenshot.sh /usr/local/bin/c64-screenshot
RUN chmod +x /usr/local/bin/c64-screenshot
COPY scripts/inputs /scripts/inputs
RUN chmod +x /scripts/inputs/*.sh 2>/dev/null || true

# Create workspace directory
WORKDIR /workspace

# Add helpful message when container starts
RUN echo '#!/bin/bash\n\
echo "╔════════════════════════════════════════════════════════════╗"\n\
echo "║   C64 Development Environment - Code Like It'"'"'s 198x      ║"\n\
echo "╚════════════════════════════════════════════════════════════╝"\n\
echo ""\n\
echo "📦 Tools installed:"\n\
echo "  • ACME assembler  - Assemble .asm to .prg"\n\
echo "  • VICE emulator   - Run C64 programs"\n\
echo "  • petcat          - Convert .bas to .prg"\n\
echo "  • c64-screenshot  - Headless screenshot capture"\n\
echo ""\n\
echo "🚀 Quick start:"\n\
echo "  acme -f cbm -o program.prg source.asm    # Assemble"\n\
echo "  x64sc program.prg                         # Run in emulator"\n\
echo "  petcat -w2 -o program.prg -- source.bas   # Convert BASIC"\n\
echo "  c64-screenshot prog.prg out.png           # Headless screenshot"\n\
echo ""\n\
echo "📚 Examples available in /workspace/examples/"\n\
echo ""\n\
' > /usr/local/bin/welcome && chmod +x /usr/local/bin/welcome

# Set default command to show welcome message
CMD ["/bin/bash", "-c", "welcome && /bin/bash"]
