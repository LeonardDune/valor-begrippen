#!/bin/bash

# Skosmos Deployment Helper Script
# Dit script helpt bij lokale testing voordat je naar production gaat

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# Kleuren voor output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function print_error() {
    echo -e "${RED}✗ $1${NC}"
}

function print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check requirements
function check_requirements() {
    print_info "Controleren op requirements..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is niet geïnstalleerd"
        exit 1
    fi
    print_success "Docker geïnstalleerd"
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is niet geïnstalleerd"
        exit 1
    fi
    print_success "Docker Compose geïnstalleerd"
}

# Setup environment
function setup_env() {
    print_info "Environment setup..."
    
    if [ ! -f .env.prod ]; then
        print_info "Kopieer .env.prod.example naar .env.prod"
        cp .env.prod.example .env.prod
        print_info ".env.prod aangemaakt - bewerk dit bestand met je instellingen"
    fi
    print_success "Environment klaar"
}

# Validate docker-compose file
function validate_compose() {
    print_info "Docker Compose bestand valideren..."
    docker-compose -f docker-compose.prod.yml config > /dev/null
    print_success "Docker Compose bestand is geldig"
}

# Build images
function build_images() {
    print_info "Docker images bouwen..."
    docker-compose -f docker-compose.prod.yml build --no-cache
    print_success "Docker images gebouwd"
}

# Start services
function start_services() {
    print_info "Services starten..."
    
    # Zorg dat frontend network bestaat
    docker network inspect frontend &> /dev/null || \
        (docker network create frontend && print_success "Frontend netwerk aangemaakt")
    
    docker-compose -f docker-compose.prod.yml up -d
    print_success "Services gestart"
}

# Check health
function check_health() {
    print_info "Wachten op services om healthy te worden..."
    
    for i in {1..30}; do
        if docker-compose -f docker-compose.prod.yml ps | grep -q "healthy"; then
            print_success "Services zijn healthy"
            return 0
        fi
        echo "   Poging $i/30..."
        sleep 2
    done
    
    print_error "Services zijn niet healthy geworden"
    docker-compose -f docker-compose.prod.yml ps
    return 1
}

# Show service info
function show_info() {
    print_info "Service informatie:"
    echo ""
    docker-compose -f docker-compose.prod.yml ps
    echo ""
    echo "Services:"
    echo "  Skosmos:       http://localhost:$(grep SKOSMOS_PORT .env.prod | cut -d= -f2)"
    echo "  Fuseki:        http://localhost:$(grep FUSEKI_PORT .env.prod | cut -d= -f2)"
    echo "  Cache:         http://localhost:$(grep CACHE_PORT .env.prod | cut -d= -f2)"
}

# Stop services
function stop_services() {
    print_info "Services stoppen..."
    docker-compose -f docker-compose.prod.yml down
    print_success "Services gestopt"
}

# View logs
function show_logs() {
    docker-compose -f docker-compose.prod.yml logs -f "$1"
}

# Clean up
function cleanup() {
    print_info "Cleanup uitvoeren..."
    docker-compose -f docker-compose.prod.yml down -v
    print_success "Docker resources verwijderd"
}

# Main menu
function show_menu() {
    echo ""
    echo "Skosmos Deployment Helper"
    echo "=========================="
    echo "1) Check requirements"
    echo "2) Setup environment"
    echo "3) Validate compose file"
    echo "4) Build images"
    echo "5) Start services (complete setup)"
    echo "6) Check health status"
    echo "7) Show service info"
    echo "8) View logs (skosmos|fuseki|fuseki-cache)"
    echo "9) Stop services"
    echo "10) Full cleanup"
    echo "0) Exit"
    echo ""
}

# Handle arguments
if [ $# -eq 0 ]; then
    # Interactive mode
    while true; do
        show_menu
        read -p "Selecteer een optie: " choice
        
        case $choice in
            1) check_requirements ;;
            2) setup_env ;;
            3) validate_compose ;;
            4) build_images ;;
            5) 
                check_requirements
                setup_env
                build_images
                start_services
                check_health
                show_info
                ;;
            6) check_health ;;
            7) show_info ;;
            8) 
                read -p "Welke service? (skosmos/fuseki/fuseki-cache): " service
                show_logs "$service"
                ;;
            9) stop_services ;;
            10) cleanup ;;
            0) exit 0 ;;
            *) print_error "Ongeldige optie" ;;
        esac
    done
else
    # Command line mode
    case "$1" in
        check) check_requirements ;;
        setup) setup_env ;;
        validate) validate_compose ;;
        build) build_images ;;
        start) 
            check_requirements
            setup_env
            build_images
            start_services
            check_health
            show_info
            ;;
        health) check_health ;;
        info) show_info ;;
        logs) show_logs "${2:-skosmos}" ;;
        stop) stop_services ;;
        clean) cleanup ;;
        *) 
            echo "Usage: $0 [check|setup|validate|build|start|health|info|logs|stop|clean]"
            exit 1
            ;;
    esac
fi
