class RandomColor {
	
	setProps(props, server) {
		this.props = props;
		this.server = server;
	}
	
	init() {
	}
    
    getRandomColorHex() {
        const colorLetters = '0123456789ABCDEF';
        let color = '';
        for (let i = 0; i < 6; i++) {
            color += colorLetters[Math.floor(Math.random() * 16)];
        }
        return color;
    }
	
	execute(currentState) {
		return new Promise((resolve, reject) => {
			const color = this.getRandomColorHex();
			if (this.props.setText) {
				currentState.text = '#' + color;
			}
			currentState.bgColor = 'ff' + color;
			resolve(currentState);
		});
	}
}

module.IdeckiaAction = RandomColor;