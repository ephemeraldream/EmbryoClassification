# main.py

import os
import argparse
import yaml
from pathlib import Path
import pytorch_lightning as pl
from pytorch_lightning.loggers import TensorBoardLogger
from pytorch_lightning.callbacks import EarlyStopping, ModelCheckpoint
from src.datamodule import ImageDataModule
from src.models import ImageClassifier
import random
import numpy as np
import torch


def seed_everything_custom(seed: int = 42):
    pl.seed_everything(seed)
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def parse_args():
    parser = argparse.ArgumentParser(description="Train Image Classification Model with PyTorch Lightning")
    parser.add_argument('--config', type=str, default='configs/config.yaml', help='Path to the config file')
    args = parser.parse_args()
    return args


def load_config(config_path: str):
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    return config


def main():
    args = parse_args()

    config = load_config(args.config)

    seed_everything_custom(config.get("seed", 42))

    data_module = ImageDataModule(
        data_dir=config['data']['data_dir'],
        batch_size=config['data']['batch_size'],
        num_workers=config['data']['num_workers'],
        img_size=config['data']['img_size'],
        augmentations=config['data']['augmentations']
    )

    model = ImageClassifier(
        model_name=config['model']['name'],
        pretrained=config['model']['pretrained'],
        num_classes=config['model']['num_classes'],
        learning_rate=config['training']['learning_rate'],
        weight_decay=config['training']['weight_decay'],
        scheduler=config['training']['scheduler'],
        scheduler_step_size=config['training']['scheduler_step_size'],
        scheduler_gamma=config['training']['scheduler_gamma'],
        optimizer=config['training'].get('optimizer', 'Adam')
    )

    logger_config = config['logger']
    if logger_config['type'] == "TensorBoardLogger":
        logger = TensorBoardLogger(
            save_dir=logger_config.get('save_dir', 'logs/'),
            name=logger_config.get('name', 'image_classification')
        )
    else:
        raise NotImplementedError(f"Logger type {logger_config['type']} not implemented.")

    callbacks = []

    if 'early_stopping' in config['callbacks']:
        es_config = config['callbacks']['early_stopping']
        early_stop_callback = EarlyStopping(
            monitor=es_config.get('monitor', 'val_loss'),
            patience=es_config.get('patience', 5),
            mode=es_config.get('mode', 'min'),
            verbose=True
        )
        callbacks.append(early_stop_callback)

    if 'model_checkpoint' in config['callbacks']:
        mc_config = config['callbacks']['model_checkpoint']
        checkpoint_callback = ModelCheckpoint(
            monitor=mc_config.get('monitor', 'val_accuracy'),
            mode=mc_config.get('mode', 'max'),
            save_top_k=mc_config.get('save_top_k', 1),
            filename=mc_config.get('filename', 'best-checkpoint'),
            verbose=True
        )
        callbacks.append(checkpoint_callback)

    trainer = pl.Trainer(
        max_epochs=config['training']['max_epochs'],
        logger=logger,
        callbacks=callbacks,
    )

    trainer.fit(model, datamodule=data_module)

    # trainer.test(model, datamodule=data_module)


if __name__ == "__main__":
    main()
